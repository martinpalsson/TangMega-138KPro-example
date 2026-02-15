//****************************************Copyright (c)***********************************//
//Technical support: www.openedv.com
//Taobao store: http://openedv.taobao.com
//Follow WeChat official account "Punctual Atom" for free FPGA & STM32 materials.
//All rights reserved. Piracy will be prosecuted.
//Copyright(C) Punctual Atom 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_write
// Last modified Date:  2018/3/18 8:41:06
// Last Version:        V1.0
// Descriptions:        SD card write data
//----------------------------------------------------------------------------------------
// Created by:          Punctual Atom
// Created date:        2018/3/18 8:41:06
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_write(
    input                clk_ref       ,  //Clock signal
    input                clk_ref_180deg,  //Clock signal, 180 degrees phase offset from sd_clk
    input                rst_n         ,  //Reset signal, active low
    //SD card interface
    input                sd_miso       ,  //SD card SPI serial input data signal
    output  reg          sd_cs         ,  //SD card SPI chip select signal
    output  reg          sd_mosi       ,  //SD card SPI serial output data signal
    //User write interface
    input                wr_start_en   ,  //Start writing SD card data signal
    input        [31:0]  wr_sec_addr   ,  //Write data sector address
    input        [15:0]  wr_data       ,  //Write data
    output  reg          wr_busy       ,  //Write data busy signal
    output  reg          wr_req           //Write data request signal
    );

//parameter define
parameter  HEAD_BYTE = 8'hfe    ;         //Data header
                             
//reg define                    
reg            wr_en_d0         ;         //wr_start_en signal delayed register
reg            wr_en_d1         ;
reg            res_en           ;         //SD card return data valid signal
reg    [7:0]   res_data         ;         //SD card return data
reg            res_flag         ;         //Flag to start receiving return data
reg    [5:0]   res_bit_cnt      ;         //Receive bit data counter

reg    [3:0]   wr_ctrl_cnt      ;         //Write control counter
reg    [47:0]  cmd_wr           ;         //Write command
reg    [5:0]   cmd_bit_cnt      ;         //Write command bit counter
reg    [3:0]   bit_cnt          ;         //Write data bit counter
reg    [8:0]   data_cnt         ;         //Write data count
reg    [15:0]  wr_data_t        ;         //Register write data to prevent changes
reg            detect_done_flag ;         //Flag to detect write idle signal
reg    [7:0]   detect_data      ;         //Detected data

//wire define
wire           pos_wr_en        ;         //Rising edge of start writing SD card data signal

//*****************************************************
//**                    main code
//*****************************************************

assign  pos_wr_en = (~wr_en_d1) & wr_en_d0;

//Delay and register wr_start_en signal
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        wr_en_d0 <= 1'b0;
        wr_en_d1 <= 1'b0;
    end    
    else begin
        wr_en_d0 <= wr_start_en;
        wr_en_d1 <= wr_en_d0;
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

//Detect if SD card is idle after writing data
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n)
        detect_data <= 8'd0;   
    else if(detect_done_flag)
        detect_data <= {detect_data[6:0],sd_miso};
    else
        detect_data <= 8'd0;    
end        

//SD card write data
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1; 
        wr_ctrl_cnt <= 4'd0;
        wr_busy <= 1'b0;
        cmd_wr <= 48'd0;
        cmd_bit_cnt <= 6'd0;
        bit_cnt <= 4'd0;
        wr_data_t <= 16'd0;
        data_cnt <= 9'd0;
        wr_req <= 1'b0;
        detect_done_flag <= 1'b0;
    end
    else begin
        wr_req <= 1'b0;
        case(wr_ctrl_cnt)
            4'd0 : begin
                wr_busy <= 1'b0;                          //Write idle
                sd_cs <= 1'b1;                                 
                sd_mosi <= 1'b1;                               
                if(pos_wr_en) begin                            
                    cmd_wr <= {8'h58,wr_sec_addr,8'hff};    //Single block write command CMD24
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;      //Increment control counter
                    //Start executing data write, assert write busy signal
                    wr_busy <= 1'b1;                      
                end                                            
            end   
            4'd1 : begin
                if(cmd_bit_cnt <= 6'd47) begin              //Start sending write command bit by bit
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= cmd_wr[6'd47 - cmd_bit_cnt]; //Send MSB first
                end    
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                        //SD card response
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;  //Increment control counter
                        cmd_bit_cnt <= 6'd0;
                        bit_cnt <= 4'd1;
                    end    
                end     
            end                                                                                                     
            4'd2 : begin                                       
                bit_cnt <= bit_cnt + 4'd1;     
                //bit_cnt = 0~7, wait 8 clock cycles
                //bit_cnt = 8~15, write command header 0xfe
                if(bit_cnt>=4'd8 && bit_cnt <= 4'd15) begin
                    sd_mosi <= HEAD_BYTE[4'd15-bit_cnt];    //Send MSB first
                    if(bit_cnt == 4'd14)                       
                        wr_req <= 1'b1;                   //Assert write data request signal in advance
                    else if(bit_cnt == 4'd15)                  
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;  //Increment control counter
                end                                            
            end                                                
            4'd3 : begin                                    //Write data
                bit_cnt <= bit_cnt + 4'd1;                     
                if(bit_cnt == 4'd0) begin                      
                    sd_mosi <= wr_data[4'd15-bit_cnt];      //Send data MSB first
                    wr_data_t <= wr_data;                   //Register data
                end                                            
                else                                           
                    sd_mosi <= wr_data_t[4'd15-bit_cnt];    //Send data MSB first
                if((bit_cnt == 4'd14) && (data_cnt < 9'd255)) 
                    wr_req <= 1'b1;                          
                if(bit_cnt == 4'd15) begin                     
                    data_cnt <= data_cnt + 9'd1;  
                    //Write a single BLOCK of 512 bytes = 256 * 16bit
                    if(data_cnt == 9'd255) begin
                        data_cnt <= 9'd0;            
                        //Data write complete, increment control counter
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;      
                    end                                        
                end                                            
            end       
            //Write 2 bytes CRC checksum, since CRC is not checked in SPI mode, write two bytes of 0xff here
            4'd4 : begin                                       
                bit_cnt <= bit_cnt + 4'd1;                  
                sd_mosi <= 1'b1;                 
                //CRC write complete, increment control counter
                if(bit_cnt == 4'd15)                           
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;            
            end                                                
            4'd5 : begin                                    
                if(res_en)                                  //SD card response
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;         
            end                                                
            4'd6 : begin                                    //Wait for write complete
                detect_done_flag <= 1'b1;                   
                //When detect_data = 8'hff, SD card write is complete, entering idle state
                if(detect_data == 8'hff) begin              
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;         
                    detect_done_flag <= 1'b0;                  
                end         
            end    
            default : begin
                //After entering idle state, assert chip select high, wait 8 clock cycles
                sd_cs <= 1'b1;   
                wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
            end     
        endcase
    end
end            

endmodule