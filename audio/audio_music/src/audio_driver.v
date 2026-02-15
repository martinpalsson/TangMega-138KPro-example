//audio driver
module audio_drive(
    input        clk_1p536m,//bit clock, each sample occupies 32 clk_1p536m cycles (16 for left and 16 for right channel)
    input        rst_n     ,//active low asynchronous reset signal
    //user data interface
    input [15:0] idata     ,
    output       req       ,//data request signal, can be connected to external FIFO read request (to avoid empty reads, AND with !fifo_empty before using as fifo_rd)
    //audio interface
    output       HP_BCK   ,//same as clk_1p536m
    output       HP_WS    ,//left/right channel select signal, low level corresponds to left channel
    output       HP_DIN    //DAC serial data input signal
);
reg [4:0] b_cnt;
reg       req_r,req_r1;//req_r1 is req_r delayed by one clock cycle
reg [15:0] idata_r;//temporary storage for idata, intermediate variable used for shift and parallel-to-serial conversion
reg HP_WS_r,HP_DIN_r;
assign HP_BCK = clk_1p536m;
assign HP_WS  = HP_WS_r   ;
assign HP_DIN = HP_DIN_r  ;
assign req    = req_r     ;
//b_cnt
always@(posedge clk_1p536m or negedge rst_n)
begin
if(!rst_n)
    b_cnt    <= 5'd0;
else
    b_cnt <= b_cnt+1'b1;
end
//req_r
always@(posedge clk_1p536m or negedge rst_n)
begin
if(!rst_n)
    req_r <= 1'b0;
else
    req_r <= (b_cnt == 5'd0) || (b_cnt == 5'd16);//read one data every 16 clock cycles
end
//idata_r
always@(posedge clk_1p536m or negedge rst_n)
begin
if(!rst_n)
    begin
    req_r1  <= 1'b0;
    idata_r <= 16'd0;
    end
else
    begin
    req_r1  <= req_r;
    idata_r <= req_r1?idata:idata_r<<1;
    end
end
//HP_DIN_r
always@(posedge clk_1p536m or negedge rst_n)
begin
if(!rst_n)
    HP_DIN_r <= 1'b0;
else
    HP_DIN_r <= idata_r[15];
end
//HP_WS_r
always@(posedge clk_1p536m or negedge rst_n)
begin
if(!rst_n)
    HP_WS_r <= 1'b0;
else
    HP_WS_r <= (b_cnt == 5'd3)?1'b0: ((b_cnt == 5'd19)?1'b1:HP_WS_r);//align data
end
endmodule