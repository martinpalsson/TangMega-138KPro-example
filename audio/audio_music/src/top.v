module top#(
    parameter clk_frequency = 50_000_000,
    parameter clk_6m_para   = 6_000_000 ,
    parameter clk_1p5m_para  = clk_6m_para/4
)(
    input        clk    ,
    input        rst    , //S1 button

    // SD spi interface
    input        sd_miso  , //SD card SPI serial input data signal
    output       sd_clk   , //SD card SPI clock signal
    output       sd_cs    , //SD card SPI chip select signal
    output       sd_mosi  , //SD card SPI serial output data signal
    
    //audio interface
    output       HP_BCK   , //same as clk_1p536m
    output       HP_WS    , //left/right channel select signal, low level corresponds to left channel
    output       HP_DIN   , //DAC serial data input signal
    output       PA_EN      //audio power amplifier enable, active high
);

wire rst_n;

assign PA_EN = 1'b1;//PA always on
assign rst_n = !rst ;

parameter start_section_parameter = 16640;
parameter file_size               = 69440;
parameter end__section_parameter  = start_section_parameter + file_size ;

wire clk_6m_w;//6MHz, used to generate 1.5MHz
wire clk_1p5m_w;//1.536MHz approximate clock

// generate clk_6m
parameter clk_6m_cnt_para = 3;
reg [clk_6m_cnt_para-1:0] clk_6m_reg = 'd0;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        clk_6m_reg <= 'd0;
    else
        clk_6m_reg <= clk_6m_reg +'b1;
end

assign clk_6m_w = clk_6m_reg[clk_6m_cnt_para-1];

// generate clk_1p5m
parameter clk_1p5m_cnt_para = 2;
reg [clk_1p5m_cnt_para-1:0] clk_1p5m_reg = 'd0;
always @(posedge clk_6m_w or negedge rst_n) begin
    if(!rst_n) 
        clk_1p5m_reg <= 'd0;
    else
        clk_1p5m_reg <= clk_1p5m_reg +'b1;
end

assign clk_1p5m_w = clk_1p5m_reg[clk_1p5m_cnt_para-1];

// read wave data

wire req_w;//read request
wire [15:0] q_w;//data read from ROM

// audio driver

wire         rd_start_en   ;  //start reading SD card data signal
wire [31:0]  rd_sec_addr   ;  //read data sector address
wire         rd_busy       ;  //read data busy signal
wire         rd_val_en     ;  //read data valid signal
wire  [15:0] rd_val_data   ;  //read data
wire         sd_init_done  ;  //SD card initialization complete signal

audio_drive u_audio_drive_0(
    .clk_1p536m(clk_1p5m_w),//bit clock, each sample occupies 32 clk_1p536m cycles (16 for left and 16 for right channel)
    .rst_n     (rst_n),//active low asynchronous reset signal
    //user data interface
    .idata     (q_w),
    .req       (req_w),//data request signal, can be connected to external FIFO read request (to avoid empty reads, AND with !fifo_empty before using as fifo_rd)
    //audio interface
    .HP_BCK   (HP_BCK_oppo),//same as clk_1p536m
    .HP_WS    (HP_WS),//left/right channel select signal, low level corresponds to left channel
    .HP_DIN   (HP_DIN)//DAC serial data input signal
);

assign HP_BCK = HP_BCK_oppo;

sd_ctrl_top   u_sd_ctrl_top(
    .clk_ref        (clk        ),  //clock signal
    .clk_ref_180deg (!clk       ),  //clock signal, 180 degrees phase shifted from clk_ref
    .rst_n          (rst_n          ),  //reset signal, active low
    //SD card interface
    .sd_miso        (sd_miso        )       ,  //SD card SPI serial input data signal
    .sd_clk         (sd_clk         )       ,  //SD card SPI clock signal
    .sd_cs          (sd_cs          )       ,  //SD card SPI chip select signal
    .sd_mosi        (sd_mosi        )       ,  //SD card SPI serial output data signal
    //user write SD card interface
    .wr_start_en    (1'b0          ),  //start writing SD card data signal
    .wr_sec_addr    (0              ),  //write data sector address
    .wr_data        (0              ),//(sd_wr_data     )       ,  //write data
    .wr_busy        (               ),  //write data busy signal
    .wr_req         (               ),  //write data request signal
    //user read SD card interface
   .rd_start_en     (rd_start_en    )   ,  //start reading SD card data signal
    .rd_sec_addr    (rd_sec_addr    )   ,  //read data sector address
    .rd_busy        (rd_busy        )   ,  //read data busy signal
    .rd_val_en      (rd_val_en      )   ,  //read data valid signal
    .rd_val_data    (rd_val_data    )   ,  //read data

    .sd_init_done   (sd_init_done   )     //SD card initialization complete signal
    );

sd_ctrl_read_top u_sd_ctrl_read_top_0(
    .sd_clk        (clk           ), //SD card working clock
    .rst_n         (rst_n         ),  //asynchronous reset, active low
    //user FIFO interface
    .rd_clk        (clk_1p5m_w    ),
    .rd_req        (req_w && !rd_empty ),  //read request
    .rd_empty      (rd_empty      ),  //FIFO empty signal
    .rd_q          (q_w           ),  //data read out
    .start_section (start_section_parameter        ),  //start sector address
    .end_section   (end__section_parameter         ),  //end sector address
    //read SD card interface
    .rd_start_en   (rd_start_en   ),  //start reading SD card data signal
    .rd_sec_addr   (rd_sec_addr   ),  //read data sector address
    .rd_busy       (rd_busy       ),  //read data busy signal
    .rd_val_en     (rd_val_en     ),  //read data valid signal
    .rd_val_data   (rd_val_data   ),  //read data
    .sd_init_done  (sd_init_done  )   //SD card initialization complete signal
    );

endmodule