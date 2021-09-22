//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         18.01.2021 
// Module Name:         BIKE_L_FUNCTION
// Description:         Wrapper to realize the L-Function. (partially created by vhd2vl)
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



import BIKE_PACKAGE::*;
import KECCAK_PACKAGE::*;



module BIKE_L_function(
    CLK,
    RESETN,
    HASH_EN,
    DONE,
    ERROR0_RDEN,
    ERROR1_RDEN,
    ERROR0_ADDR,
    ERROR1_ADDR,
    ERROR0_DIN,
    ERROR1_DIN,
    KECCAK_INIT,
    KECCAK_EN,
    KECCAK_DONE,
    KECCAK_M,
    HASH_IN,
    L_VALID,
    L_ADDR,
    L_OUT
);

input  CLK;
// CONTROL PORTS ---------------	
input  RESETN;
input  HASH_EN;
output DONE;
// ERROR BRAM ------------------
output ERROR0_RDEN;
output ERROR1_RDEN;
output [LOGDWORDS-1:0] ERROR0_ADDR;
output [LOGDWORDS-1:0] ERROR1_ADDR;
input  [31:0] ERROR0_DIN;
input  [31:0] ERROR1_DIN;
// KECCAK ----------------------
output KECCAK_INIT;
output KECCAK_EN;
input  KECCAK_DONE;
output [STATE_WIDTH - 1:0] KECCAK_M;
// L-FUNCTION ------------------
input  [L-1:0] HASH_IN;
output L_VALID;
output [2:0] L_ADDR;
output [31:0] L_OUT;

wire CLK;
wire RESETN;
wire HASH_EN;
reg  DONE;
wire ERROR0_RDEN;
wire ERROR1_RDEN;
wire [LOGDWORDS-1:0] ERROR0_ADDR;
wire [LOGDWORDS-1:0] ERROR1_ADDR;
wire [31:0] ERROR0_DIN;
wire [31:0] ERROR1_DIN;
reg  KECCAK_INIT;
reg  KECCAK_EN;
wire KECCAK_DONE;
wire [STATE_WIDTH - 1:0] KECCAK_M;
wire [L - 1:0] HASH_IN;
wire L_VALID;
wire [2:0] L_ADDR;
wire [31:0] L_OUT;



// Parameters ////////////////////////////////////////////////////////////////////
parameter integer OVER                  = 8 * (int'((R_BITS-32*(DWORDS-1))/8)+1);

parameter integer MIN_ABSORBED_BITS     = 2 * div_and_ceil(R_BITS, 8) * 8;
parameter integer MIN_ABSORBED_BYTES    = div_and_ceil(MIN_ABSORBED_BITS,8);
parameter integer ABSORBED_WORDS        = div_and_ceil(MIN_ABSORBED_BITS+4,832)*int'(832/32);//    int'($ceil(real'(((MIN_ABSORBED_BITS+4)/832)*832)/32));

parameter integer PAD_ADDR_START        = div_and_ceil(MIN_ABSORBED_BITS, 32);
parameter integer PAD_ADDR_END          = int'(ABSORBED_WORDS-1);
parameter integer PAD_BYTE_START        = int'(my_mod(MIN_ABSORBED_BYTES, 4));
 

// STATES
parameter [2:0]
  S_RESET = 0,
  S_ABSORB_INIT = 1,
  S_ABSORB = 2,
  S_ABSORB_LAST = 3,
  S_ENABLE_KECCAK = 4,
  S_WAIT = 5,
  S_L_OUT = 6,
  S_DONE = 7;

reg [2:0] STATE = S_RESET;  


// Wires and Registers ///////////////////////////////////////////////////////////
// COUNTER
reg  CNT_ADDR_EN; reg CNT_ADDR_RESETN;
wire [LOGDWORDS-1:0] CNT_ADDR_OUT;

reg  CNT_ABSORB_EN; reg CNT_ABSORB_RESETN; wire CNT_ABSORB_DONE;
wire [$clog2(832/32)-1:0] CNT_ABSORB_OUT;

wire CNT_BYTES_EN; reg CNT_BYTES_RESETN; wire CNT_BYTES_DONE;
wire [$clog2(ABSORBED_WORDS)-1:0] CNT_BYTES_OUT;  

// BRAM PORTS HASH
reg  ERROR_RDEN;
wire [LOGDWORDS-1:0] ADDR_E0; 
wire [LOGDWORDS-1:0] ADDR_E1;  

// SHA
wire [31:0] HASH_M; 
wire [31:0] M_PADDED; 
wire [31:0] HASH_M_OUT;
wire [31:0] M_PADDED_PRE_START;  

// CONTROLLING
reg  SECOND_PART; 
reg  REG_E1_EN;
wire SEC_ENABLE; 
wire DONE_ENABLE;
wire [31:0] FIRST_M; 
wire [31:0] SECOND_M; 
wire [31:0] COMP_M;
wire [31:0] SECOND_M_PRE; 
wire [31:0] SECOND_M_SWITCH; 
wire [31:0] SECOND_M_SW;
wire [OVER-1:0] INT_ERROR1;
reg  LAST;
reg  HASH_DONE;
reg  L_OUT_EN;
reg  [31:0] L_OUT_PRE;  

wire [31:0] MESSAGE [0:25];

initial begin
    $display("OVERHANG %0d", OVER);
    $display("CEIL(R_BITS/8) %0d", $ceil(real'(R_BITS)/8));
    $display("MIN_ABSORBED_BITS %0d", MIN_ABSORBED_BITS);
    $display("MIN_ABSORBED_BYTES %0d", MIN_ABSORBED_BYTES);
    $display("ABSORBED_WORDS %0d", ABSORBED_WORDS);
    $display("PAD_ADDR_START %0d", PAD_ADDR_START);
    $display("PAD_ADDR_END %0d", PAD_ADDR_END);
    $display("PAD_BYTE_START %0d", PAD_BYTE_START);
end

// Description ///////////////////////////////////////////////////////////////////

    // L OUT -----------------------------------------------------------------------
    always @(*) begin
        case(CNT_ABSORB_OUT[2:0])
            3'b 000 : L_OUT_PRE <= HASH_IN[255:224];
            3'b 001 : L_OUT_PRE <= HASH_IN[223:192];
            3'b 010 : L_OUT_PRE <= HASH_IN[191:160];
            3'b 011 : L_OUT_PRE <= HASH_IN[159:128];
            3'b 100 : L_OUT_PRE <= HASH_IN[127:96];
            3'b 101 : L_OUT_PRE <= HASH_IN[95:64];
            3'b 110 : L_OUT_PRE <= HASH_IN[63:32];
            3'b 111 : L_OUT_PRE <= HASH_IN[31:0];
            default : L_OUT_PRE <= {32{1'b0}};
        endcase
    end
    
    assign L_VALID  = L_OUT_EN;
    assign L_OUT    = L_OUT_EN == 1'b 1 ? L_OUT_PRE : {32{1'b0}};
    assign L_ADDR   = L_OUT_EN == 1'b 1 ? CNT_ABSORB_OUT[2:0] : {3{1'b0}};
    //----------------------------------------------------------------------------
    
    // DATA REORDERING -----------------------------------------------------------
    assign ERROR0_ADDR  = ADDR_E0;
    assign ERROR1_ADDR  = ADDR_E1;
    assign ERROR0_RDEN  = ERROR_RDEN;
    assign ERROR1_RDEN  = ERROR_RDEN;
    assign ADDR_E0      = CNT_ADDR_OUT;
    assign ADDR_E1      = CNT_ADDR_OUT == DWORDS-1 ? 'b0 : (CNT_ADDR_OUT+1);
  
    // MESSAGE OUT
    generate 
        for (genvar I=0; I <= 832 / 32 - 1; I = I + 1) begin: ML
            assign KECCAK_M[32 * I + 31:32 * I] = MESSAGE[I];
        end
    endgenerate
    assign KECCAK_M[STATE_WIDTH - 1:832] = {(((STATE_WIDTH - 1))-((832))+1){1'b0}};
    
    generate 
        for (genvar I=0; I <= 25; I = I + 1) begin: ASSIGN_M
            assign MESSAGE[I] = ((CNT_ABSORB_OUT)) == I ? HASH_M_OUT : {1{1'b0}};
        end
    endgenerate
  
    assign HASH_M_OUT = CNT_BYTES_OUT < PAD_ADDR_START ? HASH_M : M_PADDED;
    

    generate 
        if (PAD_ADDR_START == PAD_ADDR_END) begin: G0
            if (PAD_BYTE_START == 2) begin: G00
                assign M_PADDED = {1'b1, {11{1'b0}}, 3'b110, HASH_M[15:0]};
            end
    
            if (PAD_BYTE_START == 0) begin: G01
                assign M_PADDED = {1'b1, {27{1'b0}}, 3'b110};
            end
        end
    endgenerate
  
    generate 
        if (PAD_ADDR_START != PAD_ADDR_END) begin: G1
            if (PAD_BYTE_START == 2) begin: G10
                assign M_PADDED_PRE_START = {{12{1'b0}}, 3'b110, HASH_M[15:0]};
                assign M_PADDED = (CNT_BYTES_OUT == (PAD_ADDR_START)) ? M_PADDED_PRE_START : CNT_BYTES_OUT == ABSORBED_WORDS ? {1'b1, {31{1'b0}}} : 'b0;
            end
            
            if (PAD_BYTE_START == 0) begin: G11
                assign M_PADDED_PRE_START = {{28{1'b0}}, 3'b110};
                assign M_PADDED = (CNT_BYTES_OUT == (PAD_ADDR_START+1)) ? M_PADDED_PRE_START : CNT_BYTES_OUT == ABSORBED_WORDS ? {1'b1, {31{1'b0}}} : 'b0;
            end
            
            
        end
    endgenerate
  
    // input data need to be rearranged as our memory layout differs that from the reference implementation
    assign HASH_M = SECOND_PART == 1'b0 ? FIRST_M : COMP_M;
    
    // reordering for e0
    assign FIRST_M = ERROR0_DIN;
    
    // reordering for switching between e0 and e1
    assign SECOND_M_SWITCH = {ERROR1_DIN[(32-OVER-1):0], ERROR0_DIN[(OVER-1):0]};
    assign SECOND_M_SW = SECOND_M_SWITCH;
    
    // reordering for e1
    assign SECOND_M_PRE = {ERROR1_DIN[32 - OVER - 1:0],INT_ERROR1};
    assign SECOND_M = SECOND_M_PRE;
    
    assign COMP_M = CNT_BYTES_OUT == DWORDS ? SECOND_M_SW : SECOND_M;
  
  
    // store higher bits in a register
    RegisterFDRE #(.SIZE(OVER)) 
    reg_e2_part(.clk(CLK), .resetn(RESETN), .enable(REG_E1_EN), .d(ERROR1_DIN[31:(32-OVER)]), .q(INT_ERROR1)); 
  
    // INDICATE SECOND PART
    assign SEC_ENABLE = (CNT_BYTES_OUT == (DWORDS-1)) ? 1'b1 : 1'b0;
    
    always @(posedge CLK) begin
        if(~RESETN) begin
            SECOND_PART <= 1'b0;
        end
        else begin
            if(SEC_ENABLE) begin
                SECOND_PART <= 1'b1;
            end
        end
    end

    always @(posedge CLK) begin
        LAST <= SECOND_PART;
    end

    // done
    assign DONE_ENABLE = CNT_BYTES_DONE;
    
    always @(posedge CLK) begin
        if(~RESETN) begin
            HASH_DONE <= 1'b 0;
        end
        else begin
            if(DONE_ENABLE) begin
                HASH_DONE <= 1'b 1;
            end
        end
    end
    //----------------------------------------------------------------------------
      
    // COUNTER -------------------------------------------------------------------
    BIKE_counter_inc #(.SIZE(LOGDWORDS), .MAX_VALUE(DWORDS-1))
    cnt_addr (.clk(CLK), .enable(CNT_ADDR_EN), .resetn(CNT_ADDR_RESETN), .cnt_out(CNT_ADDR_OUT));
    
    assign CNT_ABSORB_DONE = CNT_ABSORB_OUT == int'(832/32-3) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(832/32))), .MAX_VALUE(int'(832/32-1)))
    cnt_absorb (.clk(CLK), .enable(CNT_ABSORB_EN), .resetn(CNT_ABSORB_RESETN), .cnt_out(CNT_ABSORB_OUT));

    assign CNT_BYTES_EN = CNT_ADDR_EN;
    assign CNT_BYTES_DONE = CNT_BYTES_OUT == (ABSORBED_WORDS-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(ABSORBED_WORDS))), .MAX_VALUE(ABSORBED_WORDS))
    cnt_bytes (.clk(CLK), .enable(CNT_BYTES_EN), .resetn(CNT_BYTES_RESETN), .cnt_out(CNT_BYTES_OUT)); 	
    //----------------------------------------------------------------------------
    
    // FINITE STATE MACHINE ------------------------------------------------------
    always @(posedge CLK) begin
        // GLOBAL -----------------
        DONE                <= 1'b0;
        
        // COUNTER ----------------
        CNT_ADDR_RESETN     <= 1'b0;
        CNT_ADDR_EN         <= 1'b0;
        CNT_ABSORB_RESETN   <= 1'b0;
        CNT_ABSORB_EN       <= 1'b0;
        CNT_BYTES_RESETN    <= 1'b0;
        
        // BRAM -------------------
        ERROR_RDEN          <= 1'b0;
        
        // KECCAK -----------------
        KECCAK_INIT         <= 1'b0;
        KECCAK_EN           <= 1'b0;
        
        // INTERNAL ---------------
        L_OUT_EN            <= 1'b0;
        REG_E1_EN           <= 1'b0;
        
        case(STATE)
            //--------------------------------------------
            S_RESET : begin
                // TRANSITION ------
                if(HASH_EN) begin
                    STATE           <= S_ABSORB_INIT;
                end
                else begin
                    STATE           <= S_RESET;
                end
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_ABSORB_INIT : begin
                // COUNTER ---------
                CNT_ADDR_RESETN     <= 1'b1;
                CNT_ADDR_EN         <= 1'b1;
                CNT_BYTES_RESETN    <= 1'b1;
                
                // BRAM -------------------
                ERROR_RDEN          <= 1'b1;
                
                // TRANSITION ------
                STATE <= S_ABSORB;
            end
            //--------------------------------------------	
            
            //--------------------------------------------
            S_ABSORB : begin
                // COUNTER ---------
                CNT_ADDR_RESETN     <= 1'b1;
                CNT_ADDR_EN         <= 1'b1;
                CNT_ABSORB_RESETN   <= 1'b1;
                CNT_ABSORB_EN       <= 1'b1;
                CNT_BYTES_RESETN    <= 1'b1;
                
                // BRAM -------------------
                ERROR_RDEN          <= 1'b1;
                
                // KECCAK ----------
                KECCAK_INIT         <= 1'b1;
                REG_E1_EN           <= 1'b1;
                
                // TRANSITION ------
                if(CNT_ABSORB_DONE) begin
                    STATE           <= S_ABSORB_LAST;
                end
                else begin
                    STATE           <= S_ABSORB;
                end
            end
            //--------------------------------------------
            				
            //--------------------------------------------
            S_ABSORB_LAST : begin
                // COUNTER ---------
                CNT_ADDR_RESETN     <= 1'b1;
                CNT_ABSORB_RESETN   <= 1'b1;
                CNT_ABSORB_EN       <= 1'b1;
                CNT_BYTES_RESETN    <= 1'b1;
                
                // KECCAK ----------
                KECCAK_INIT         <= 1'b1;
                REG_E1_EN           <= 1'b1;
                
                // TRANSITION ------
                STATE               <= S_ENABLE_KECCAK;
            end
            //--------------------------------------------	
            
            //--------------------------------------------
            S_ENABLE_KECCAK : begin
                // COUNTER ---------
                CNT_ADDR_RESETN     <= 1'b1;
                CNT_BYTES_RESETN    <= 1'b1;
                
                // KECCAK ----------
                KECCAK_EN           <= 1'b1;
                
                // TRANSITION ------
                STATE               <= S_WAIT;
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_WAIT : begin
                // COUNTER ---------
                CNT_ADDR_RESETN     <= 1'b1;
                CNT_BYTES_RESETN    <= 1'b1;
                
                // TRANSITION ------
                if(KECCAK_DONE) begin
                    if(HASH_DONE) begin
                        STATE       <= S_L_OUT;
                    end
                    else begin
                        STATE       <= S_ABSORB_INIT;
                    end
                end
                else begin
                    STATE           <= S_WAIT;
                end
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_L_OUT : begin
                // COUNTER ---------
                CNT_ABSORB_RESETN   <= 1'b1;
                CNT_ABSORB_EN       <= 1'b1;
                
                // INTERNAL --------
                L_OUT_EN            <= 1'b1;
                
                // TRANSITION ------
                if(CNT_ABSORB_OUT == 6) begin
                    STATE           <= S_DONE;
                end
                else begin
                    STATE           <= S_L_OUT;
                end
            end
            //--------------------------------------------   
            
            //--------------------------------------------
            S_DONE : begin
                DONE <= 1'b 1;
                
                // COUNTER ---------
                CNT_ADDR_RESETN     <= 1'b0;
                CNT_BYTES_RESETN    <= 1'b0;
                
                // TRANSITION ------
                if(~RESETN) begin
                    STATE           <= S_RESET;
                end
                else begin
                    STATE           <= S_DONE;
                end
            end
            //--------------------------------------------                                              
        endcase
    end
    //----------------------------------------------------------------------------

endmodule
