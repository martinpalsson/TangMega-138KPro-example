//****************************************Copyright (c)***********************************//
//Technical support: www.openedv.com
//Taobao store: http://openedv.taobao.com
//Follow WeChat official account "Punctual Atom" for free FPGA & STM32 materials.
//All rights reserved. Piracy will be prosecuted.
//Copyright(C) Punctual Atom 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_read
// Last modified Date:  2018/3/18 8:41:06
// Last Version:        V1.0
// Descriptions:        SD card read data
//----------------------------------------------------------------------------------------
// Created by:          Punctual Atom
// Created date:        2018/3/18 8:41:06
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_read(
    input                clk_ref       ,  //Clock signal
    input                clk_ref_180deg,  //Clock signal, 180 degrees phase offset from sd_clk
    input                rst_n         ,  //Reset signal, active low
    //SD card interface
    input                sd_miso       ,  //SD card SPI serial input data signal
    output  reg          sd_cs         ,  //SD card SPI chip select signal
    output  reg          sd_mosi       ,  //SD card SPI serial output data signal
    //User read interface
    input                rd_start_en   ,  //Start reading SD card data signal
    input        [31:0]  rd_sec_addr   ,  //Read data sector address
    output  reg          rd_busy       ,  //Read data busy signal
    output  reg          rd_val_en     ,  //Read data valid signal
    output  reg  [15:0]  rd_val_data      //Read data
    );

//reg define
reg            rd_en_d0      ;            //rd_start_en signal delayed register
reg            rd_en_d1      ;
reg            res_en        ;            //SD card return data valid signal
reg    [7:0]   res_data      ;            //SD card return data
reg            res_flag      ;            //Flag to start receiving return data
reg    [5:0]   res_bit_cnt   ;            //Receive bit data counter

reg            rx_en_t       ;            //SD card data receive enable signal
reg    [15:0]  rx_data_t     ;            //SD card received data
reg            rx_flag       ;            //Flag to start receiving
reg    [3:0]   rx_bit_cnt    ;            //Receive data bit counter
reg    [8:0]   rx_data_cnt   ;            //Received data count counter
reg            rx_finish_en  ;            //Receive complete enable signal

reg    [3:0]   rd_ctrl_cnt   ;            //Read control counter
reg    [47:0]  cmd_rd        ;            //Read command
reg    [5:0]   cmd_bit_cnt   ;            //Read command bit counter
reg            rd_data_flag  ;            //Flag indicating ready to read data

//wire define
wire           pos_rd_en     ;            //Rising edge of start reading SD card data signal

//*****************************************************
//**                    main code
//*****************************************************

assign  pos_rd_en = (~rd_en_d1) & rd_en_d0;

//Delay and register rd_start_en signal
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_en_d0 <= 1'b0;
        rd_en_d1 <= 1'b0;
    end    
    else begin
        rd_en_d0 <= rd_start_en;
        rd_en_d1 <= rd_en_d0;
    end        
end  

//Receive response data returned from SD card
//Latch data on rising edge of clk_ref_180deg (sd_clk)
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 8'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end
    else begin
        //sd_miso = 0, start receiving response data
        if(sd_miso == 1'b0 && res_flag == 1'b0) begin
            res_flag <= 1'b1;
            res_data <= {res_data[6:0],sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            res_en <= 1'b0;
        end    
        else if(res_flag) begin
            res_data <= {res_data[6:0],sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            if(res_bit_cnt == 6'd7) begin
                res_flag <= 1'b0;
                res_bit_cnt <= 6'd0;
                res_en <= 1'b1; 
            end                
        end  
        else
            res_en <= 1'b0;        
    end
end 

//Receive valid data from SD card
//Latch data on rising edge of clk_ref_180deg (sd_clk)
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        rx_en_t <= 1'b0;
        rx_data_t <= 16'd0;
        rx_flag <= 1'b0;
        rx_bit_cnt <= 4'd0;
        rx_data_cnt <= 9'd0;
        rx_finish_en <= 1'b0;
    end    
    else begin
        rx_en_t <= 1'b0; 
        rx_finish_en <= 1'b0;
        //Data header 0xfe = 8'b1111_1110, so detect 0 as start bit
        if(rd_data_flag && sd_miso == 1'b0 && rx_flag == 1'b0)    
            rx_flag <= 1'b1;   
        else if(rx_flag) begin
            rx_bit_cnt <= rx_bit_cnt + 4'd1;
            rx_data_t <= {rx_data_t[14:0],sd_miso};
            if(rx_bit_cnt == 4'd15) begin 
                rx_data_cnt <= rx_data_cnt + 9'd1;
                //Receive a single BLOCK of 512 bytes = 256 * 16bit
                if(rx_data_cnt <= 9'd255)                        
                    rx_en_t <= 1'b1;  
                else if(rx_data_cnt == 9'd257) begin   //Receive two bytes of CRC checksum
                    rx_flag <= 1'b0;
                    rx_finish_en <= 1'b1;              //Data reception complete
                    rx_data_cnt <= 9'd0;               
                    rx_bit_cnt <= 4'd0;
                end    
            end                
        end       
        else
            rx_data_t <= 16'd0;
    end    
end    

//Register output data valid signal and data
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_val_en <= 1'b0;
        rd_val_data <= 16'd0;
    end
    else begin
        if(rx_en_t) begin
            rd_val_en <= 1'b1;
            rd_val_data <= rx_data_t;
        end    
        else
            rd_val_en <= 1'b0;
    end
end              

//Read command
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;        
        rd_ctrl_cnt <= 4'd0;
        cmd_rd <= 48'd0;
        cmd_bit_cnt <= 6'd0;
        rd_busy <= 1'b0;
        rd_data_flag <= 1'b0;
    end   
    else begin
        case(rd_ctrl_cnt)
            4'd0 : begin
                rd_busy <= 1'b0;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
                if(pos_rd_en) begin
                    cmd_rd <= {8'h51,rd_sec_addr,8'hff};    //Single block read command CMD17
                    rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;      //Increment control counter
                    //Start executing data read, assert read busy signal
                    rd_busy <= 1'b1;                      
                end    
            end
            4'd1 : begin
                if(cmd_bit_cnt <= 6'd47) begin              //Start sending read command bit by bit
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= cmd_rd[6'd47 - cmd_bit_cnt]; //Send MSB first
                end    
                else begin                                  
                    sd_mosi <= 1'b1;
                    if(res_en) begin                        //SD card response
                        rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;  //Increment control counter
                        cmd_bit_cnt <= 6'd0;
                    end    
                end    
            end    
            4'd2 : begin
                //Assert rd_data_flag signal, ready to receive data
                rd_data_flag <= 1'b1;                       
                if(rx_finish_en) begin                      //Data reception complete
                    rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1; 
                    rd_data_flag <= 1'b0;
                    sd_cs <= 1'b1;
                end
            end        
            default : begin
                //After entering idle state, assert chip select high, wait 8 clock cycles
                sd_cs <= 1'b1;   
                rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;
            end    
        endcase
    end         
end

endmodule