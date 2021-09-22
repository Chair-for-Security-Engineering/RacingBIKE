//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.01.2021 
// Module Name:         KECCAK_RC
// Description:         Provides round constants for KECCAK.
// 
// Dependencies:        None.
// 
// Revision:        
// Revision             0.01 - File Created
// Usage Information:   Please look at readme.txt. If licence.txt or readme.txt
//						are missing or	if you have questions regarding the code						
//						please contact Jan Richter-Brockmann (jan.richter-brockmann@rub.de)
//
//                      THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY 
//                      KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//                      IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
//                      PARTICULAR PURPOSE.
//
//////////////////////////////////////////////////////////////////////////////////

import KECCAK_PACKAGE::*;

module KECCAK_RC(
    round,
    const_out
);

input [4:0] round;
output [LANE_WIDTH - 1:0] const_out;

wire [4:0] round;
wire [LANE_WIDTH - 1:0] const_out;


// SIGNALS -----------------------------------------------------------------------
reg [63:0] const_signal;  // BEHAVIORAL --------------------------------------------------------------------

    always @(round) begin
        case(round)
            5'b 00000 : begin
              const_signal <= 64'h 0000000000000001;
            end
            5'b 00001 : begin
              const_signal <= 64'h 0000000000008082;
            end
            5'b 00010 : begin
              const_signal <= 64'h 800000000000808A;
            end
            5'b 00011 : begin
              const_signal <= 64'h 8000000080008000;
            end
            5'b 00100 : begin
              const_signal <= 64'h 000000000000808B;
            end
            5'b 00101 : begin
              const_signal <= 64'h 0000000080000001;
            end
            5'b 00110 : begin
              const_signal <= 64'h 8000000080008081;
            end
            5'b 00111 : begin
              const_signal <= 64'h 8000000000008009;
            end
            5'b 01000 : begin
              const_signal <= 64'h 000000000000008A;
            end
            5'b 01001 : begin
              const_signal <= 64'h 0000000000000088;
            end
            5'b 01010 : begin
              const_signal <= 64'h 0000000080008009;
            end
            5'b 01011 : begin
              const_signal <= 64'h 000000008000000A;
            end
            5'b 01100 : begin
              const_signal <= 64'h 000000008000808B;
            end
            5'b 01101 : begin
              const_signal <= 64'h 800000000000008B;
            end
            5'b 01110 : begin
              const_signal <= 64'h 8000000000008089;
            end
            5'b 01111 : begin
              const_signal <= 64'h 8000000000008003;
            end
            5'b 10000 : begin
              const_signal <= 64'h 8000000000008002;
            end
            5'b 10001 : begin
              const_signal <= 64'h 8000000000000080;
            end
            5'b 10010 : begin
              const_signal <= 64'h 000000000000800A;
            end
            5'b 10011 : begin
              const_signal <= 64'h 800000008000000A;
            end
            5'b 10100 : begin
              const_signal <= 64'h 8000000080008081;
            end
            5'b 10101 : begin
              const_signal <= 64'h 8000000000008080;
            end
            5'b 10110 : begin
              const_signal <= 64'h 0000000080000001;
            end
            5'b 10111 : begin
              const_signal <= 64'h 8000000080008008;
            end
            default : begin
              const_signal <= {64{1'b0}};
            end
        endcase
    end

  assign const_out = const_signal[LANE_WIDTH - 1:0];

endmodule
