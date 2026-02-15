//****************************************Copyright (c)***********************************//
//Technical support: www.openedv.com
//Taobao store: http://openedv.taobao.com
//Follow WeChat official account "Punctual Atom" for free FPGA & STM32 materials.
//All rights reserved. Piracy will be prosecuted.
//Copyright(C) Punctual Atom 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_ctrl_top
// Last modified Date:  2018/3/18 8:41:06
// Last Version:        V1.0
// Descriptions:        SD card top-level control module
//----------------------------------------------------------------------------------------
// Created by:          Punctual Atom
// Created date:        2018/3/18 8:41:06
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_ctrl_top(
    input                clk_ref       ,  //Clock signal
    input                clk_ref_180deg,  //Clock signal, 180 degrees phase offset from clk_ref
    input                rst_n         ,  //Reset signal, active low
    //SD card interface
    input                sd_miso       ,  //SD card SPI serial input data signal
    output               sd_clk        ,  //SD card SPI clock signal
    output  reg          sd_cs         ,  //SD card SPI chip select signal
    output  reg          sd_mosi       ,  //SD card SPI serial output data signal
    //User write SD card interface
    input                wr_start_en   ,  //Start writing SD card data signal
    input        [31:0]  wr_sec_addr   ,  //Write data sector address
    input        [15:0]  wr_data       ,  //Write data
    output               wr_busy       ,  //Write data busy signal
    output               wr_req        ,  //Write data request signal
    //User read SD card interface
    input                rd_start_en   ,  //Start reading SD card data signal
    input        [31:0]  rd_sec_addr   ,  //Read data sector address
    output               rd_busy       ,  //Read data busy signal
    output               rd_val_en     ,  //Read data valid signal
    output       [15:0]  rd_val_data   ,  //Read data

    output               sd_init_done     //SD card initialization complete signal
    );

//wire define
wire                init_sd_cs    ;       //Initialization module SD chip select signal
wire                init_sd_mosi  ;       //Initialization module SD data output signal
wire                wr_sd_cs      ;       //Write data module SD chip select signal
wire                wr_sd_mosi    ;       //Write data module SD data output signal
wire                rd_sd_cs      ;       //Read data module SD chip select signal
wire                rd_sd_mosi    ;       //Read data module SD data output signal

//*****************************************************
//**                    main code
//*****************************************************

assign  sd_clk = clk_ref_180deg;          //SD card SPI_CLK

//SD card interface signal selection
always @(*) begin
    //Before SD card initialization is complete, port signals are connected to initialization module signals
    if(sd_init_done == 1'b0) begin     
        sd_cs <= init_sd_cs;
        sd_mosi <= init_sd_mosi;
    end    
    else if(wr_busy) begin
        sd_cs <= wr_sd_cs;
        sd_mosi <= wr_sd_mosi;      
    end    
    else if(rd_busy) begin
        sd_cs <= rd_sd_cs;
        sd_mosi <= rd_sd_mosi;        
    end    
    else begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;
    end    
end    

//SD card initialization
sd_init u_sd_init(
    .clk_ref            (clk_ref),
    .clk_ref_180deg     (clk_ref_180deg),
    .rst_n              (rst_n),
    
    .sd_miso            (sd_miso),
    .sd_cs              (init_sd_cs),
    .sd_mosi            (init_sd_mosi),
    
    .sd_init_done       (sd_init_done)
    );

//SD card write data
sd_write u_sd_write(
    .clk_ref            (clk_ref),
    .clk_ref_180deg     (clk_ref_180deg),
    .rst_n              (rst_n),
    
    .sd_miso            (sd_miso),
    .sd_cs              (wr_sd_cs),
    .sd_mosi            (wr_sd_mosi),
    //Respond to write operations after SD card initialization is complete
    .wr_start_en        (wr_start_en & sd_init_done),  
    .wr_sec_addr        (wr_sec_addr),
    .wr_data            (wr_data),
    .wr_busy            (wr_busy),
    .wr_req             (wr_req)
    );

//SD card read data
sd_read u_sd_read(
    .clk_ref            (clk_ref),
    .clk_ref_180deg     (clk_ref_180deg),
    .rst_n              (rst_n),
    
    .sd_miso            (sd_miso),
    .sd_cs              (rd_sd_cs),
    .sd_mosi            (rd_sd_mosi),    
    //Respond to read operations after SD card initialization is complete
    .rd_start_en        (rd_start_en & sd_init_done),  
    .rd_sec_addr        (rd_sec_addr),
    .rd_busy            (rd_busy),
    .rd_val_en          (rd_val_en),
    .rd_val_data        (rd_val_data)
    );

endmodule