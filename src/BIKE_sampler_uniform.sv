//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.01.2021 
// Module Name:         BIKE_sampler_uniform
// Description:         Sampler for uniform strings. (partially created by vhd2vl)
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


module BIKE_sampler_uniform
    #(
        parameter SAMPLE_LENGTH=256
    )(
        CLK,
        RESETN,
        ENABLE,
        DONE,
        RAND_VALID,
        RAND_REQU,
        NEW_RAND,
        WREN,
        ADDR,
        DOUT
);



input CLK;

// CONTROL PORTS ---------------	
input  RESETN;
input  ENABLE;
output DONE;

// RAND ------------------------
input  RAND_VALID;
output RAND_REQU;
input  [31:0] NEW_RAND;

// MEMORY I/O ------------------
output WREN;
output [$clog2(int'(SAMPLE_LENGTH/32)):0] ADDR;         
output [31:0] DOUT;

wire CLK;
wire RESETN;
wire ENABLE;
reg  DONE;

wire RAND_VALID;
wire RAND_REQU;
wire [31:0] NEW_RAND;
wire WREN;
wire [$clog2(int'(SAMPLE_LENGTH/32)):0] ADDR;         
wire [31:0] DOUT;
wire [31:0] DOUT_PRE;


// COUNTER
reg  CNT_RESETN; 
wire CNT_ENABLE; 
wire CNT_DONE;
reg  [$clog2(int'(SAMPLE_LENGTH/32)):0] CNT_OUT;

// Internal
wire LAST_BLOCK; 
reg  INT_ENABLE; 
wire INT_VALID;

// STATES
//--------------------------------------------------------------------------------
parameter [1:0]
  S_RESET = 0,
  S_SAMPLE = 1,
  S_DONE = 2;

reg [1:0] STATE = S_RESET;  

wire rand_valid_buf;


// Behavioral
//--------------------------------------------------------------------------------

    // WRITE RANDOMNESS TO BRAM --------------------------------------------------
    assign RAND_REQU = CNT_OUT <= int'($ceil(real'(SAMPLE_LENGTH)/32)-1) ? INT_ENABLE : 1'b0; 
    
    assign ADDR = CNT_OUT;
    assign DOUT = INT_VALID == 1'b1 ? DOUT_PRE : {32{1'b0}};
    assign WREN = INT_VALID;
    
    generate if ((SAMPLE_LENGTH % 32) == 0) begin: I0 
        assign DOUT_PRE = NEW_RAND;
    end endgenerate
    
    generate if ((SAMPLE_LENGTH % 32) != 0) begin: I1
        assign DOUT_PRE = LAST_BLOCK == 1'b0 ? NEW_RAND : {{32-(SAMPLE_LENGTH%32){1'b0}}, NEW_RAND[(SAMPLE_LENGTH%32-1):0]}; 
    end endgenerate
    
    assign LAST_BLOCK = CNT_OUT == int'($ceil(real'(SAMPLE_LENGTH)/32)-1) ? 1'b1 : 1'b0; 
    assign INT_VALID = CNT_OUT < int'($ceil(real'(SAMPLE_LENGTH)/32)) ? (RAND_VALID && INT_ENABLE) : {32{1'b0}};
    //----------------------------------------------------------------------------
  
    // COUNTER ------------------------------------------------------------------- 
    assign CNT_ENABLE = RAND_VALID == 1'b1 ? INT_ENABLE : 1'b0;
    assign CNT_DONE = CNT_OUT == int'($ceil(real'(SAMPLE_LENGTH)/32)-1) ? RAND_VALID : 1'b0;
    BIKE_counter_inc_stop #(.SIZE($clog2(int'(SAMPLE_LENGTH/32))+1), .MAX_VALUE(int'($ceil(real'(SAMPLE_LENGTH)/32)))) 
    COUNTER (.clk(CLK), .enable(CNT_ENABLE), .resetn(CNT_RESETN), .cnt_out(CNT_OUT));
    //----------------------------------------------------------------------------
  
    // FINITE STATE MACHINE PROCESS ----------------------------------------------
    always @(posedge CLK) begin
        case(STATE)
        
            //--------------------------------------------
            S_RESET : begin
                // GLOBAL ----------
                DONE            <= 1'b0;
                
                // BRAM ------------
                INT_ENABLE      <= 1'b0;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b0;
                
                // TRANSITION ------
                if((ENABLE == 1'b1)) begin
                    STATE       <= S_SAMPLE;
                end
                else begin
                    STATE       <= S_RESET;
                end
            end
            //--------------------------------------------
          
            //--------------------------------------------
            S_SAMPLE : begin
                // GLOBAL ----------
                DONE            <= 1'b0;
                
                // BRAM ------------
                INT_ENABLE      <= 1'b1;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b1;
                
                // TRANSITION ------
                if(CNT_DONE) begin
                    STATE       <= S_DONE;
                end 
                else begin
                    STATE       <= S_SAMPLE;
                end
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_DONE : begin
                // GLOBAL ----------
                DONE            <= 1'b1;

                // BRAM ------------
                INT_ENABLE      <= 1'b0;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b0;
                
                // TRANSITION ------
                if((RESETN == 1'b0)) begin
                    STATE       <= S_RESET;
                end
                else begin
                    STATE       <= S_DONE;
                end
            end
            //--------------------------------------------
        endcase
    end
    //----------------------------------------------------------------------------

endmodule
