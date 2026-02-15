//****************************************Copyright (c)***********************************//
//Technical support: www.openedv.com
//Taobao store: http://openedv.taobao.com
//Follow WeChat official account "Punctual Atom" for free FPGA & STM32 materials.
//All rights reserved. Piracy will be prosecuted.
//Copyright(C) Punctual Atom 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_init
// Last modified Date:  2018/3/18 8:41:06
// Last Version:        V1.0
// Descriptions:        SD card initialization
//----------------------------------------------------------------------------------------
// Created by:          Punctual Atom
// Created date:        2018/3/18 8:41:06
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_init(
    input          clk_ref       ,  //Clock signal
    input          clk_ref_180deg,  //Clock signal, 180 degrees phase offset from clk_ref
    input          rst_n         ,  //Reset signal, active low

    input          sd_miso       ,  //SD card SPI serial input data signal
    output  reg    sd_cs         ,  //SD card SPI chip select signal
    output  reg    sd_mosi       ,  //SD card SPI serial output data signal
    output  reg    sd_init_done     //SD card initialization complete signal
    );

//parameter define
//SD card software reset command, since command number and parameters are fixed values, CRC is also fixed, CRC = 8'h95
parameter  CMD0  = {8'h40,8'h00,8'h00,8'h00,8'h00,8'h95};
//Interface condition command, sends host device voltage range, used to distinguish SD card version, only 2.0 and later cards support CMD8
//MMC cards and V1.x cards do not support this command, since command number and parameters are fixed values, CRC is also fixed, CRC = 8'h87
parameter  CMD8  = {8'h48,8'h00,8'h00,8'h01,8'haa,8'h87};
//Tell SD card the next command is an application-specific command, not a standard command, CRC not required
parameter  CMD55 = {8'h77,8'h00,8'h00,8'h00,8'h00,8'hff};  
//Send operation condition register (OCR) content, CRC not required
parameter  ACMD41= {8'h69,8'h40,8'h00,8'h00,8'h00,8'hff};
//Wait at least 74 synchronous clock cycles after power-on, during power-on stabilization period, sd_cs = 1, sd_mosi = 1
parameter  POWER_ON_NUM = 74;
//Maximum wait time for SD card response when sending software reset command, T = 500ms
//When timeout counter equals this value, SD card response is considered timed out, resend software reset command
parameter  OVER_TIME_NUM = 25'd25_000_000; 
                                           
parameter  st_idle        = 7'b000_0001;  //Default state, power-on wait for SD card to stabilize
parameter  st_send_cmd0   = 7'b000_0010;  //Send software reset command
parameter  st_wait_cmd0   = 7'b000_0100;  //Wait for SD card response
parameter  st_send_cmd8   = 7'b000_1000;  //Send host voltage range, check if SD card meets requirements
parameter  st_send_cmd55  = 7'b001_0000;  //Tell SD card the next command is application-specific
parameter  st_send_acmd41 = 7'b010_0000;  //Send operation condition register (OCR) content
parameter  st_init_done   = 7'b100_0000;  //SD card initialization complete

//reg define
reg    [7:0]   cur_state    ;
reg    [7:0]   next_state   ; 
                            
reg    [7:0]   poweron_cnt  ;  //Power-on stabilization wait counter
reg            res_en       ;  //SD card return data valid signal
reg    [47:0]  res_data     ;  //SD card return data
reg            res_flag     ;  //Flag to start receiving return data
reg    [5:0]   res_bit_cnt  ;  //Receive bit data counter

reg    [5:0]   cmd_bit_cnt  ;  //Send command bit counter
reg   [24:0]   over_time_cnt;  //Timeout counter
reg            over_time_en ;  //Timeout enable signal

//*****************************************************
//**                    main code
//*****************************************************

//Power-on stabilization wait counter
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) 
        poweron_cnt <= 8'd0;
    else if(poweron_cnt < POWER_ON_NUM + 3'd6) 
        poweron_cnt <= poweron_cnt + 1'b1;
end    

//Receive response data returned from SD card
//Latch data on rising edge of clk_ref_180deg (sd_clk)
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 48'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end
    else begin
        //sd_miso = 0, start receiving response data
        if(sd_miso == 1'b0 && res_flag == 1'b0) begin 
            res_flag <= 1'b1;
            res_data <= {res_data[46:0],sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            res_en <= 1'b0;
        end    
        else if(res_flag) begin
            //R1 returns 1 byte, R3 R7 return 5 bytes
            //Here we uniformly receive 6 bytes, the extra 1 byte is NOP (8 clock cycles delay)
            res_data <= {res_data[46:0],sd_miso};     
            res_bit_cnt <= res_bit_cnt + 6'd1;
            if(res_bit_cnt == 6'd47) begin
                res_flag <= 1'b0;
                res_bit_cnt <= 6'd0;
                res_en <= 1'b1; 
            end                
        end  
        else
            res_en <= 1'b0;         
    end
end                    

always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end

always @(*) begin
    next_state = st_idle;
    case(cur_state)
        st_idle : begin
            //Wait at least 74 synchronous clock cycles after power-on, add a few extra cycles for safety
            if(poweron_cnt == POWER_ON_NUM + 3'd6)   //Default state, power-on wait for SD card to stabilize
                next_state = st_send_cmd0;
            else
                next_state = st_idle;
        end 
        st_send_cmd0 : begin                         //Send software reset command
            if(cmd_bit_cnt == 6'd47)
                next_state = st_wait_cmd0;
            else
                next_state = st_send_cmd0;    
        end               
        st_wait_cmd0 : begin                         //Wait for SD card response
            if(res_en) begin                         //SD card returns response signal
                if(res_data[47:40] == 8'h01)         //SD card returns reset success
                    next_state = st_send_cmd8;
                else
                    next_state = st_send_cmd0;
            end
            else if(over_time_en)                    //SD card response timeout
                next_state = st_send_cmd0;
            else
                next_state = st_wait_cmd0;                                    
        end    
        //Send host voltage range, check if SD card meets requirements
        st_send_cmd8 : begin
            if(res_en) begin                         //SD card returns response signal
                //Return SD card operating voltage, [19:16] = 4'b0001 (2.7V~3.6V)
                if(res_data[19:16] == 4'b0001)       
                    next_state = st_send_cmd55;
                else
                    next_state = st_send_cmd8;
            end
            else
                next_state = st_send_cmd8;            
        end
        //Tell SD card the next command is application-specific
        st_send_cmd55 : begin
            if(res_en) begin                         //SD card returns response signal
                if(res_data[47:40] == 8'h01)         //SD card returns idle state
                    next_state = st_send_acmd41;
                else
                    next_state = st_send_cmd55;    
            end        
            else
                next_state = st_send_cmd55;     
        end  
        st_send_acmd41 : begin                       //Send operation condition register (OCR) content
            if(res_en) begin                         //SD card returns response signal
                if(res_data[47:40] == 8'h00)         //Initialization complete signal
                    next_state = st_init_done;
                else
                    next_state = st_send_cmd55;      //Initialization not complete, retry
            end
            else
                next_state = st_send_acmd41;     
        end                
        st_init_done : next_state = st_init_done;    //Initialization complete
        default : next_state = st_idle;
    endcase
end

//SD card latches data on the rising edge of clk_ref_180deg (sd_clk), so data is output on the falling edge of clk_ref_180deg
//To uniformly use rising edge triggers in always blocks, a clock with 180 degree phase offset from clk_ref_180deg is used here
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;
        sd_init_done <= 1'b0;
        cmd_bit_cnt <= 6'd0;
        over_time_cnt <= 25'd0;
        over_time_en <= 1'b0;
    end
    else begin
        over_time_en <= 1'b0;
        case(cur_state)
            st_idle : begin                               //Default state, power-on wait for SD card to stabilize
                sd_cs <= 1'b1;                            //During power-on stabilization period, sd_cs=1
                sd_mosi <= 1'b1;                          //sd_mosi=1
            end     
            st_send_cmd0 : begin                          //Send CMD0 software reset command
                cmd_bit_cnt <= cmd_bit_cnt + 6'd1;        
                sd_cs <= 1'b0;                            
                sd_mosi <= CMD0[6'd47 - cmd_bit_cnt];     //Send CMD0 command MSB first
                if(cmd_bit_cnt == 6'd47)                  
                    cmd_bit_cnt <= 6'd0;                  
            end      
            //During CMD0 response reception, chip select CS is held low, entering SPI mode
            st_wait_cmd0 : begin
                sd_mosi <= 1'b1;
                if(res_en)                                //SD card returns response signal
                    //Pull high after reception is complete, entering SPI mode
                    sd_cs <= 1'b1;                                      
                over_time_cnt <= over_time_cnt + 1'b1;    //Timeout counter starts counting
                //SD card response timeout, resend software reset command
                if(over_time_cnt == OVER_TIME_NUM - 1'b1)
                    over_time_en <= 1'b1;
                if(over_time_en)
                    over_time_cnt <= 25'd0;                                        
            end                                           
            st_send_cmd8 : begin                          //Send CMD8
                if(cmd_bit_cnt<=6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= CMD8[6'd47 - cmd_bit_cnt]; //Send CMD8 command MSB first
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                      //SD card returns response signal
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            st_send_cmd55 : begin                         //Send CMD55
                if(cmd_bit_cnt<=6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= CMD55[6'd47 - cmd_bit_cnt];       
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                      //SD card returns response signal
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            st_send_acmd41 : begin                        //Send ACMD41
                if(cmd_bit_cnt <= 6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= ACMD41[6'd47 - cmd_bit_cnt];      
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                      //SD card returns response signal
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            st_init_done : begin                          //Initialization complete
                sd_init_done <= 1'b1;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
            end
            default : begin
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;                
            end    
        endcase
    end
end

endmodule