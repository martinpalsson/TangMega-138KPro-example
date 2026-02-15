module top#(
	parameter BOARD_MAC 	= 48'h11_45_14_19_19_81 		,//Board MAC address
	parameter BOARD_IP 		= {8'd192,8'd168,8'd3,8'd2}	, 	//Board IP address
	parameter BOARD_PORT	= 16'h8000, 					 //Board IP address - port
	parameter DES_MAC 		= 48'hff_ff_ff_ff_ff_ff 		,//Destination MAC address
	parameter DES_IP 		= {8'd192,8'd168,8'd3,8'd3} 	,//Destination IP address
	parameter DES_PORT		= 16'h8000, 					 //Destination IP address - port
	parameter DATA_SIZE		= 16'd256						 //Packet length 46~1500 B
	)(
	input 			sys_clk,
	input 			rst_n, 			


	output 			PHY_CLK,
	output 			RGMII_GTXCLK,
	output 			RGMII_RST_N, 	
	output [3:0] 	RGMII_TXD, 		
	output reg		RGMII_TXEN		
	);
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
//////////////////// 			    GMII Transmit Submodule 	        /////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
GMII_pll GMII_pll_m0(
	.clkin 		(sys_clk 	 	),
	.clkout0 	(RGMII_GTXCLK 	),
	.clkout1 	(PHY_CLK 		)
	);	

wire GMII_TXEN;
wire [7:0] GMII_TXD;
GMII_send #(
	.BOARD_MAC 	(BOARD_MAC  ),//Board MAC address
	.BOARD_IP 	(BOARD_IP 	),//Board IP address
	.BOARD_PORT (BOARD_PORT ),
	.DES_MAC 	(DES_MAC 	),//Destination MAC address
	.DES_IP 	(DES_IP 	),//Destination IP address
	.DES_PORT 	(DES_PORT 	),
	.DATA_SIZE	(DATA_SIZE	) //Packet length 50~1500B
	)GMII_send_m0(
	.rst_n 			(rst_n 				),

	.GMII_GTXCLK 	(RGMII_GTXCLK 		),
	.GMII_TXD 		(GMII_TXD 			),
	.GMII_TXEN 		(GMII_TXEN 			),
	.GMII_TXER 		(	 				)
	);
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
//////////////////// 			    GMII 2 RGMII	        /////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
reg [7:0] GMII_TXD_R;
always@(posedge RGMII_GTXCLK) GMII_TXD_R <= GMII_TXD;

GMII2RGMII GMII2RGMII_m0(
	.clk 		(RGMII_GTXCLK 		),
	.din 		(GMII_TXD_R 		),
	.q 			(RGMII_TXD 			)
	);

reg [2:0] GMII_TXEN_R;
always@(posedge RGMII_GTXCLK) GMII_TXEN_R <= {GMII_TXEN_R[1:0],GMII_TXEN};
always@(posedge RGMII_GTXCLK) RGMII_TXEN <= GMII_TXEN_R[2];

assign RGMII_RST_N = rst_n;

endmodule