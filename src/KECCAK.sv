//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.01.2021 
// Module Name:         KECCAK
// Description:         KECCAK topmodule (partially translated with vhd2vl).
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

module KECCAK(
    CLK,
    RESETN,
    ENABLE,
    INIT,
    DONE,
    M,
    KECCAK_OUT
);

input CLK;
input RESETN;
input ENABLE;
input INIT;
output DONE;

input [STATE_WIDTH - 1:0] M;            // message

output [STATE_WIDTH - 1:0] KECCAK_OUT;  // hash

wire CLK;
wire RESETN;
wire ENABLE;
wire INIT;
wire DONE;
wire [STATE_WIDTH-1:0] M;
wire [STATE_WIDTH-1:0] KECCAK_OUT;


// wires and register ////////////////////////////////////////////////////////////
wire [LANE_WIDTH-1:0] STATE_IN [4:0][4:0];
wire [LANE_WIDTH-1:0] STATE_IN_M [4:0][4:0];
wire [LANE_WIDTH-1:0] STATE_OUT [4:0][4:0];
reg  [LANE_WIDTH-1:0] STATE_OUT_REG [4:0][4:0];
wire [LANE_WIDTH-1:0] STATE_OUT_REG_IN [4:0][4:0];
wire [4:0] ROUND_NUMBER = 0;
wire [4:0] ROUND_NUMBER_IN = 0;

wire USE_M = 1'b1; 
wire ABSORB;
wire [(RATE-1):0] M_PART;  

// counter
wire OUT_EN; 
wire CNT_EN_ROUND; 
wire CNT_RST_ROUND;
wire [(CNT_LENGTH_ROUND - 1):0] CNT_ROUND;

wire ENABLE_ROUND;



// Description ///////////////////////////////////////////////////////////////////

    // STATE REGISTER -----------------------------------------------------------
    assign STATE_OUT_REG_IN = INIT == 1'b 1 ? STATE_IN_M : STATE_OUT;
  
    always @(posedge CLK) begin
        if(~RESETN) begin 
            for (int y=0; y <= 4; y = y + 1) begin 
                for (int x=0; x <= 4; x = x + 1) begin
                    for (int z=0; z <= LANE_WIDTH - 1; z = z + 1) begin
                        STATE_OUT_REG[x][y][z] <= 1'b0; 
                    end
                end
            end
        end
        else begin
            if((ENABLE_ROUND == 1'b 1 || INIT == 1'b 1)) begin
                STATE_OUT_REG <= STATE_OUT_REG_IN;
            end
            else begin
                STATE_OUT_REG <= STATE_OUT_REG;
            end
        end
    end
    //----------------------------------------------------------------------------

    // Conversions ---------------------------------------------------------------
    // mapping input std_logic_vector to state matrix
    generate 
        for (genvar y=0; y <= 4; y = y + 1) begin: f001
            for (genvar x=0; x <= 4; x = x + 1) begin: f002
                for (genvar z=0; z <= LANE_WIDTH - 1; z = z + 1) begin: f003
                    assign STATE_IN_M[x][y][z] = STATE_OUT_REG[x][y][z] ^ M[(LANE_WIDTH*(y*5+x)+z)]; 
                end
            end
        end
    endgenerate
  
  
    // mapping state matrix to std_logic_vector
    generate 
    for (genvar y=0; y <= 4; y = y + 1) begin: o001
        for (genvar x=0; x <= 4; x = x + 1) begin: o002
            for (genvar z=0; z <= LANE_WIDTH / 8 - 1; z = z + 1) begin: o003
                if (((x + y * 5) * LANE_WIDTH + z) < STATE_WIDTH) begin: o004
                    assign KECCAK_OUT[STATE_WIDTH-1-((x+y*5)*LANE_WIDTH + 8*z):(STATE_WIDTH-((x+y*5)*LANE_WIDTH + 8*z+8))] = STATE_OUT_REG[x][y][(8*z+7):(8*z)];
                end
            end
        end
    end
    endgenerate
    //----------------------------------------------------------------------------
    
    
    // KECCAK ROUND FUNCTION -----------------------------------------------------
    assign STATE_IN = STATE_OUT_REG;
    
    KECCAK_round keccak_round(.state_in(STATE_IN), .state_out(STATE_OUT), .round_number(CNT_ROUND));
    //----------------------------------------------------------------------------
    
    
    // ROUND COUNTER -------------------------------------------------------------
    BIKE_counter_inc #(.SIZE(CNT_LENGTH_ROUND), .MAX_VALUE(N_R-1)) 
    counter_round(
        .clk(CLK),
        .resetn(CNT_RST_ROUND),
        .enable(CNT_EN_ROUND),
        .cnt_out(CNT_ROUND)
        
    );
    //----------------------------------------------------------------------------
    
    
    // FSM -----------------------------------------------------------------------
    KECCAK_controller keccak_controller (
        .CLK(CLK),
        .EN(ENABLE),
        .RESETN(RESETN),
        .ENABLE_ROUND(ENABLE_ROUND),
        .DONE(DONE),
        .CNT_EN_ROUND(CNT_EN_ROUND),
        .CNT_RST_ROUND(CNT_RST_ROUND),
        .CNT_ROUND(CNT_ROUND)
    );
    //----------------------------------------------------------------------------

endmodule
