module GMII_send#(
	parameter BOARD_MAC 	= 48'h03_08_35_01_AE_C2 		,// Board MAC address
	parameter BOARD_IP 		= {8'd192,8'd168,8'd3,8'd2}	,// Board IP address
	parameter BOARD_PORT	= 16'h8000, 					 // Board port
	parameter DES_MAC 		= 48'hff_ff_ff_ff_ff_ff 		,// Destination MAC address
	parameter DES_IP 		= {8'd192,8'd168,8'd3,8'd3} 	,// Destination IP address
	parameter DES_PORT		= 16'h8000, 					 // Destination port
	parameter DATA_SIZE		= 16'd1472 						 // Packet data length 32~1500 B
	)(
	input  				rst_n,

	input 				GMII_GTXCLK,
	output reg  [7:0] 	GMII_TXD,
	output reg 			GMII_TXEN,
	output reg			GMII_TXER
	);

/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
////////////////////              Packet Transmit              //////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
localparam IP_HEAD_CODE = 64'h55_55_55_55_55_55_55_d5;  // 7 preamble bytes (0x55) + 1 start-of-frame delimiter (0xD5)
localparam DES_MAC_CODE = DES_MAC; // Destination MAC address (ff-ff-ff-ff-ff-ff = broadcast)
localparam BOARD_MAC_CODE = BOARD_MAC; // Board MAC address
localparam DATA_TYPE = 16'H0800; // EtherType (IPv4)
localparam MAC_DATA = {DES_MAC,BOARD_MAC,16'h0800}; // Dest MAC + Source MAC + EtherType

reg [31:0] packet_header [6:0];     // IP header fields
reg [31:0] check_buffer; // Checksum temporary variable

localparam IDLE        = 4'd0;
localparam CHECK_SUM   = 4'd1;
localparam PACKET_HEAD = 4'd2;
localparam SEND_MAC    = 4'd3;
localparam SEND_HEADER = 4'd4;
localparam SEND_DATA   = 4'd5;
localparam SEND_CRC    = 4'd6;
localparam DELAY       = 4'd7;

reg [ 3:0] state;
reg [10:0] send_cnt;

wire [31:0] 	crc_data;
reg 		 	crc_en;

always@(posedge GMII_GTXCLK)begin
	if(!rst_n)begin
		send_cnt 	<= 'd0;
		state 		<= IDLE;
	end
	else
		case(state)
			IDLE:begin
				send_cnt 		<= 'd0;

				GMII_TXEN 		<= 'b0;
				GMII_TXER 		<= 'd0;
				GMII_TXD  		<= 'd0;

				if(1)begin
					//IP header
					packet_header[0] <= {16'h4500,DATA_SIZE+16'd28};  	// Version: 4, Header len: 20, Total IP length (data + 20B header)
					packet_header[1] <= {{5'b00000,11'd0},16'h4000};    // Packet sequence number + Fragment offset
					packet_header[2] <= {8'h80,8'h11,16'h0000};         // TTL + UDP protocol + blank IP header checksum
					packet_header[3] <= BOARD_IP;                   	// Source IP address (board)
					packet_header[4] <= DES_IP;                   		// Destination IP address
					packet_header[5] <= {BOARD_PORT,DES_PORT};          // 2-byte source port + 2-byte destination port
					packet_header[6] <= {DATA_SIZE+16'd8,16'h0000};     // UDP length + UDP checksum (unused)

				 	state <= CHECK_SUM;
				 end
			end

			CHECK_SUM:begin  //---------- Compute header checksum
				send_cnt <= (send_cnt == 2) ? 11'd0 : send_cnt + 11'd1; // Counter only, not transmitting

				case(send_cnt)
					'd0: check_buffer <= ((packet_header[0][15:0]+packet_header[0][31:16])+(packet_header[1][15:0]
						+packet_header[1][31:16]))+(((packet_header[2][15:0]+packet_header[2][31:16])+((packet_header[3][15:0]
						+packet_header[3][31:16])))+(packet_header[4][15:0]+packet_header[4][31:16]));
					'd1: check_buffer[15:0] <= check_buffer[31:16]+check_buffer[15:0];
					'd2: packet_header[2][15:0] <= ~check_buffer[15:0];                 // Header checksum
				endcase

				state <= (send_cnt == 2) ? PACKET_HEAD : state;
			end

			PACKET_HEAD:begin//---------- Send 8-byte preamble: 7x 0x55 + 1x 0xD5
				send_cnt 	<= (send_cnt == 7) ? 11'd0 : send_cnt + 11'd1;

				GMII_TXEN 	<= 'b1;
				GMII_TXD 	<= IP_HEAD_CODE[(7-send_cnt)*8 +: 8];

				state <= (send_cnt == 7) ? SEND_MAC : state;
			end

			SEND_MAC:begin //------------ Send dest MAC + source MAC + EtherType, start CRC
				send_cnt 	<= (send_cnt == 13) ? 11'd0 : send_cnt + 11'd1;
				crc_en 		<= 'b1;

				GMII_TXD 	<= MAC_DATA [(13-send_cnt)*8 +: 8] ;

				state 		<= (send_cnt == 13) ? SEND_HEADER : state;
			end

			SEND_HEADER:begin //--------- Send 7x 32-bit IP header words
				send_cnt 	<= (send_cnt == 'd27) ? 11'd0 : send_cnt + 11'd1;

				GMII_TXD 	<= packet_header[send_cnt[10:2]][(3 - send_cnt[1:0]) * 8 +: 8];

				state <= (send_cnt == 'd27) ? SEND_DATA : state;
			end

			SEND_DATA:begin //----------- Send payload data
				send_cnt 		<= (send_cnt == DATA_SIZE-1) ? 11'd0 : send_cnt + 11'd1;

				GMII_TXD 		<= 16'HF0; // Repeated test pattern

				state 			<= (send_cnt == DATA_SIZE-1) ? SEND_CRC: state;
			end

			SEND_CRC:begin //------------ Send CRC (FCS)
				send_cnt 		<= (send_cnt == 'd3) ? 11'd0 : send_cnt + 11'd1;
				crc_en 			<= 'b0;

				case(send_cnt)
					'd0: GMII_TXD <= {~crc_data[24], ~crc_data[25], ~crc_data[26], ~crc_data[27],
									 ~crc_data[28], ~crc_data[29], ~crc_data[30], ~crc_data[31]};
					'd1: GMII_TXD <= {~crc_data[16], ~crc_data[17], ~crc_data[18], ~crc_data[19],
								 	 ~crc_data[20], ~crc_data[21], ~crc_data[22], ~crc_data[23]};
					'd2: GMII_TXD <= {~crc_data[8], ~crc_data[9], ~crc_data[10], ~crc_data[11],
									 ~crc_data[12], ~crc_data[13], ~crc_data[14], ~crc_data[15]};
					'd3: GMII_TXD <= {~crc_data[0], ~crc_data[1], ~crc_data[2], ~crc_data[3],
									 ~crc_data[4], ~crc_data[5], ~crc_data[6], ~crc_data[7]};
					default: GMII_TXER <= 'd1;
				endcase

				state 			<= (send_cnt == 'd3)? DELAY: state;
			end

			DELAY:begin//------------ Wait for inter-frame gap
				send_cnt <= send_cnt[3] ? 11'd0 : send_cnt + 11'd1;

				GMII_TXEN 		<= 'b0;
				GMII_TXER 		<= 'd0;
				GMII_TXD  		<= 'd0;

				state <= send_cnt [3] ? IDLE : state;
			end

			default: state <= IDLE;
		endcase
end


/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
////////////////////              CRC Calculation              //////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////

crc crc32_m0(
	.Clk		(~GMII_GTXCLK 	),
	.Reset		(1'b0 			),
	.Data_in	(GMII_TXD 		),
	.Enable		(crc_en 		),
	.Crc		(crc_data 		),
	.CrcNext	(  				)
	);


endmodule
