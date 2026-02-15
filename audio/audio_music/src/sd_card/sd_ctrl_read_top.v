//Function: SD card controller read module with FIFO interface
//Usage:
//When not reading data, pull rst_n low. Pull rst_n high when reading is needed. While rst_n is high, as long as the FIFO is not full,
//it will continuously read data from sectors start_section to end_section in a loop.
module sd_ctrl_read_top(
    input             sd_clk, //SD card working clock
    input             rst_n,  //Asynchronous reset, active low
    //User FIFO interface
    input             rd_clk,
    input             rd_req,       //Read request
    output            rd_empty,     //FIFO empty signal
    output [15:0]     rd_q,         //Read data output
    input  [31:0]     start_section,//Start sector address
    input  [31:0]     end_section,  //End sector address
    //SD card read interface
    output            rd_start_en   ,  //Start reading SD card data signal
    output     [31:0] rd_sec_addr   ,  //Read data sector address
    input             rd_busy       ,  //Read data busy signal
    input             rd_val_en     ,  //Read data valid signal
    input [15:0]      rd_val_data   ,  //Read data
    input             sd_init_done     //SD card initialization complete signal
    );
wire fifo_almost_full;//This signal goes high when FIFO usedw reaches 512
wire [9:0]  wrusedw_w;//FIFO depth is 1024
assign fifo_almost_full = (wrusedw_w >= 10'd512);//Reserve enough space to prevent write overflow
sd_ctrl_read u_sd_ctrl_read_0(
    .sd_clk           (sd_clk),  //SD card working clock
    .rst_n            (rst_n),  //Asynchronous reset, active low
    //User interface
    .start_section    (start_section ),  //Start sector address
    .end_section      (end_section   ),  //End sector address
    //FIFO almost full signal
    .fifo_almost_full (fifo_almost_full),
    //SD card read interface
    .rd_start_en      (rd_start_en   ),  //Start reading SD card data signal
    .rd_sec_addr      (rd_sec_addr   ),  //Read data sector address
    .rd_busy          (rd_busy       ),  //Read data busy signal
    .sd_init_done     (sd_init_done  )   //SD card initialization complete signal
    ); 
sd_ctrl_dcfifo u_sd_ctrl_dcfifo_0(
    .Data(rd_val_data), //input [15:0] Data
    .Reset(!rst_n), //input Reset
    .WrClk(sd_clk), //input WrClk
    .RdClk(rd_clk), //input RdClk
    .WrEn(rd_val_en), //input WrEn
    .RdEn(rd_req), //input RdEn
    .Wnum(wrusedw_w), //output [10:0] Wnum
    //.Almost_Empty(Almost_Empty_o), //output Almost_Empty
    .Q(rd_q) ,//output [15:0] Q
    .Empty(rd_empty) //output Empty
    //.Full(Full_o) //output Full
);
endmodule