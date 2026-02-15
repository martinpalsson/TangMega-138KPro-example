module top#(
    parameter clk_frequency = 50_000_000,
    parameter clk_6m_para   = 6_000_000 ,
    parameter clk_1p5m_para  = clk_6m_para/4
)(
    input        clk    ,
    input        rst    , //S1 button

    //audio interface
    output       HP_BCK   , //same as clk_1p536m
    output       HP_WS    , //left/right channel select signal, low level corresponds to left channel
    output       HP_DIN   , //DAC serial data input signal
    output       PA_EN      //audio power amplifier enable, active high
);

wire rst_n;

assign PA_EN = 1'b1;//PA always on
assign rst_n = !rst ;

wire clk_6m_w;//6MHz, used to generate 1.5MHz
wire clk_1p5m_w;//1.536MHz approximate clock

// generate clk_6m
parameter clk_6m_cnt_para = clk_frequency/clk_6m_para  ;
reg [$clog2(clk_6m_cnt_para):0] clk_6m_cnt_reg;
reg clk_6m;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        clk_6m_cnt_reg <= 'd0;
        clk_6m <= 'd0;
    end else if(clk_6m_cnt_reg > clk_6m_cnt_para-1) begin
        clk_6m_cnt_reg <= 'd0;
        clk_6m <= ~clk_6m;        
    end else begin
        clk_6m_cnt_reg <= clk_6m_cnt_reg + 'b1;
        clk_6m <= clk_6m;        
    end    
end

assign clk_6m_w = clk_6m;

// generate clk_1p5m
parameter clk_1p5m_cnt_para = clk_frequency/clk_1p5m_para  ;
reg [$clog2(clk_1p5m_cnt_para):0] clk_1p5m_cnt_reg;
reg clk_1p5m;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        clk_1p5m_cnt_reg <= 'd0;
        clk_1p5m <= 'd0;
    end else if(clk_1p5m_cnt_reg > clk_1p5m_cnt_para-1) begin
        clk_1p5m_cnt_reg <= 'd0;
        clk_1p5m <= ~clk_1p5m;        
    end else begin
        clk_1p5m_cnt_reg <= clk_1p5m_cnt_reg + 'b1;
        clk_1p5m <= clk_1p5m;        
    end    
end

assign clk_1p5m_w = clk_1p5m;

// read wave data

wire req_w;//read request
wire [15:0] q_w;//data read from ROM

rom_save_sin rom_save_sin_inst(
.clk(clk),
.rst_n(rst_n),
.data(q_w)
);

// audio driver
audio_drive u_audio_drive_0(
    .clk_1p536m(clk_1p5m_w),//bit clock, each sample occupies 32 clk_1p536m cycles (16 for left and 16 for right channel)
    .rst_n     (rst_n),//active low asynchronous reset signal
    //user data interface
    .idata     (q_w),
    .req       (req_w),//data request signal, can be connected to external FIFO read request (to avoid empty reads, AND with !fifo_empty before using as fifo_rd)
    //audio interface
    .HP_BCK   (HP_BCK),//same as clk_1p536m
    .HP_WS    (HP_WS),//left/right channel select signal, low level corresponds to left channel
    .HP_DIN   (HP_DIN)//DAC serial data input signal
);

endmodule