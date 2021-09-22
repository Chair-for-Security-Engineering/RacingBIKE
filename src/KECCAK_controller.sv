//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.01.2021 
// Module Name:         KECCAK_CONTROLLER
// Description:         FSM for KECCAK (partially translated with vhd2vl).
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

module KECCAK_controller(
    CLK,
    EN,
    RESETN,
    ENABLE_ROUND,
    DONE,
    CNT_EN_ROUND,
    CNT_RST_ROUND,
    CNT_ROUND
);

input CLK;
input EN;
input RESETN;
output ENABLE_ROUND;
output DONE;
// COUNTER ---------------------------
output CNT_EN_ROUND;
output CNT_RST_ROUND;
input [(CNT_LENGTH_ROUND - 1):0] CNT_ROUND;

wire CLK;
wire EN;
wire RESETN;
reg  ENABLE_ROUND;
reg  DONE;
reg  CNT_EN_ROUND;
reg  CNT_RST_ROUND;
wire [(CNT_LENGTH_ROUND - 1):0] CNT_ROUND;

// FSM states
parameter [1:0]
  S_RESET = 0,
  S_PERMUT = 1,
  S_RDY_SQUEEZE = 2;

reg [1:0] STATE = S_RESET; 

    // FINITE STATE MACHINE ////////////////////////////////////////////////////////
    always @(posedge CLK) begin
        // GLOBAL -------
        DONE                <= 1'b0;
        
        // COUNTER ------
        CNT_EN_ROUND        <= 1'b0;
        CNT_RST_ROUND       <= 1'b0;
        
        // INTERALS -----
        ENABLE_ROUND        <= 1'b 0;
        
        case(STATE)
            //--------------------------------------------------------------------
            S_RESET : begin
                // TRANSITION ---------
                if((EN == 1'b 1)) begin
                    STATE           <= S_PERMUT;
                    ENABLE_ROUND    <= 1'b1;
                    CNT_EN_ROUND    <= 1'b1;
                    CNT_RST_ROUND   <= 1'b1;
                end
                else begin
                    STATE           <= S_RESET;
                end
            end
            
            S_PERMUT : begin
                // INTERALS ----------
                ENABLE_ROUND        <= 1'b1;
                
                // COUNTER ------------
                CNT_EN_ROUND        <= 1'b1;
                CNT_RST_ROUND       <= 1'b1;
                
                // TRANSITION ---------
                if(CNT_ROUND == N_R-2) begin
                    STATE           <= S_RDY_SQUEEZE;
                end
                else begin
                    STATE           <= S_PERMUT;
                end
            end
            
            S_RDY_SQUEEZE : begin
                // INTERNALS ----------
                DONE <= 1'b 1;
                // TRANSITION ---------
                STATE <= S_RESET;
            end
            //--------------------------------------------------------------------
        endcase
    end


endmodule
