module top#(
)(
	input 		clk,  //Input clock source

	output      WS2812
);

ws2812 ws2812_inst(
	.clk(clk),  //Input clock source
	.WS2812(WS2812) //Output interface to WS2812
);

endmodule