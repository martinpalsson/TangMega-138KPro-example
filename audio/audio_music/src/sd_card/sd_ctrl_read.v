//Function: SD card read control module with FIFO interface, supports multi-sector cyclic reading
module sd_ctrl_read(
    input             sd_clk, //SD card working clock
    input             rst_n,  //Asynchronous reset, active low
    //User interface
    input  [31:0]     start_section,//Start sector address
    input  [31:0]     end_section,  //End sector address
    //FIFO almost full signal
    input             fifo_almost_full,
    //SD card read interface
    output reg        rd_start_en   ,  //Start reading SD card data signal
    output reg [31:0] rd_sec_addr   ,  //Read data sector address
    input             rd_busy       ,  //Read data busy signal
    input             sd_init_done     //SD card initialization complete signal
    );

//reg define
reg    [1:0]          rd_flow_cnt      ;    //Read data flow control counter
reg                   rd_busy_d0       ;    //Read busy signal delayed, used to capture falling edge
reg                   rd_busy_d1       ;
//wire define
wire neg_rd_busy;
wire read_able_w;//Read-ready flag signal
assign read_able_w = (sd_init_done && !rd_busy && !fifo_almost_full);//Cannot read SD card data when FIFO almost full signal is high, otherwise data has nowhere to be stored
//Delay and register rd_busy signal, used to capture the falling edge of rd_busy
assign  neg_rd_busy = rd_busy_d1 & (~rd_busy_d0);
always @(posedge sd_clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        rd_busy_d0 <= 1'b0;
        rd_busy_d1 <= 1'b0;
    end
    else begin
        rd_busy_d0 <= rd_busy;
        rd_busy_d1 <= rd_busy_d0;
    end
end
//Read data from SD card
always @(posedge sd_clk or negedge rst_n) 
begin
if(!rst_n) begin
    rd_flow_cnt <= 2'd0;
    rd_start_en <= 1'b0;
    rd_sec_addr <= 32'd0;
end
else begin
	case(rd_flow_cnt)
	2'd0 : begin//Wait for SD card initialization to complete, then enter read data state
		rd_sec_addr <= start_section;//Output read sector address register, initialized to start sector address
		rd_flow_cnt <= read_able_w?2'd1 : rd_flow_cnt;
		rd_start_en <= read_able_w;
	end
	2'd1 : begin//Check if one sector read is complete, neg_rd_busy high means done
	    rd_start_en <= 1'b0;
		rd_flow_cnt <= neg_rd_busy?2'd2:2'd1;//When neg_rd_busy falling edge detected, prepare to start next sector read
	    rd_sec_addr <= neg_rd_busy?rd_sec_addr+1:rd_sec_addr;    //Increment sector address on neg_rd_busy                 
	end
   2'd2:begin
	    rd_start_en <= (rd_sec_addr <= end_section) && !fifo_almost_full;//Only start a sector read when read buffer FIFO has enough space
		 if(rd_sec_addr > end_section)//If sector to read exceeds end_section, return to state 2'd0
		     rd_flow_cnt <= 2'd0;
		 else if(!fifo_almost_full)   //If sector to read does not exceed end_section and read buffer FIFO has enough space, start a sector read
		     rd_flow_cnt <= 2'd1;
		 else                         //Otherwise keep waiting for !fifo_almost_full
		     rd_flow_cnt <= 2'd2;
	end
	default : ;
	endcase    
    end
end
endmodule