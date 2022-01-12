//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         25.01.2021 
// Module Name:         BIKE_K_FUNCTION
// Description:         Wrapper to realize the K-Function. (partially created by vhd2vl)
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



module BIKE_k_function(
    CLK,
    RESETN,
    HASH_EN,
    DONE,
    M_L,
    C1_L,
    C0_RDEN,
    C0_ADDR,
    C0,
    KECCAK_INIT,
    KECCAK_EN,
    KECCAK_DONE,
    KECCAK_M,
    HASH_IN,
    K_VALID,
    K_ADDR,
    K_OUT
);

input  CLK;

// CONTROL PORTS ---------------	
input  RESETN;
input  HASH_EN;
output DONE;

// DATA ------------------------
input  [255:0] M_L;
input  [255:0] C1_L;
output C0_RDEN;
output [LOGDWORDS-1:0] C0_ADDR;
input  [31:0] C0;

// KECCAK ----------------------
output KECCAK_INIT;
output KECCAK_EN;
input  KECCAK_DONE;
output [STATE_WIDTH-1:0] KECCAK_M;

// K-FUNCTION ------------------
input  [L - 1:0] HASH_IN;
output K_VALID;
output [2:0] K_ADDR;
output [31:0] K_OUT;

wire CLK;
wire RESETN;
wire HASH_EN;
reg  DONE;
wire [255:0] M_L;
wire [255:0] C1_L;
wire C0_RDEN;
wire [LOGDWORDS-1:0] C0_ADDR;
wire [31:0] C0;
reg  KECCAK_INIT;
reg  KECCAK_EN;
wire KECCAK_DONE;
wire [STATE_WIDTH-1:0] KECCAK_M;
wire [L-1:0] HASH_IN;
wire K_VALID;
wire [2:0] K_ADDR;
wire [31:0] K_OUT;


// Parameters ////////////////////////////////////////////////////////////////////
parameter integer OVER                  = 8 * (int'((R_BITS-32*(DWORDS-1))/8)+1);

parameter integer MIN_ABSORBED_BITS     = div_and_ceil(R_BITS, 8)*8+2*256;
parameter integer MIN_ABSORBED_BYTES    = div_and_ceil(MIN_ABSORBED_BITS,8);
parameter integer ABSORBED_WORDS        = div_and_ceil(MIN_ABSORBED_BITS+4,832)*int'(832/32);//    int'($ceil(real'(((MIN_ABSORBED_BITS+4)/832)*832)/32));

parameter integer PAD_ADDR_START        = div_and_ceil(MIN_ABSORBED_BITS, 32);
parameter integer PAD_ADDR_END          = int'(ABSORBED_WORDS-1);
parameter integer PAD_BYTE_START        = int'(my_mod(MIN_ABSORBED_BYTES, 4));

parameter integer NUM_LOWER_BYTES       = div_and_ceil(OVER, 8); //int'($ceil(real'(OVER)/8));



// States 
parameter [2:0]
  S_RESET           = 0,
  S_ABSORB_INIT     = 1,
  S_ABSORB          = 2,
  S_ABSORB_LAST     = 3,
  S_ENABLE_KECCAK   = 4,
  S_WAIT            = 5,
  S_L_OUT           = 6,
  S_DONE            = 7;

reg [2:0] STATE = S_RESET;  



// Wires and Registers ///////////////////////////////////////////////////////////
// COUNTER
reg  CNT_REG_EN; wire CNT_REG_EN_D; wire CNT_REG_RSTN;  
wire [int'($clog2(int'($ceil(real'(L)/32))))-1:0] CNT_REG_OUT;

wire CNT_ADDR_EN; reg CNT_ADDR_RSTN;  
wire [LOGDWORDS-1:0] CNT_ADDR_OUT;

reg  CNT_ABSORB_EN; reg CNT_ABSORB_RSTN; wire CNT_ABSORB_DONE;  
wire [int'($clog2(832/32))-1:0] CNT_ABSORB_OUT;

reg  CNT_BYTES_EN; reg CNT_BYTES_RSTN; wire CNT_BYTES_DONE;  
wire [int'($clog2(ABSORBED_WORDS))-1:0] CNT_BYTES_OUT;

// SHA
reg  [31:0] HASH_M; wire [31:0] M_PADDED; wire [31:0] HASH_M_OUT;
wire [31:0] M_PADDED_PRE_START;  

// CONTROLLING
reg  [2:0] SEL_HASH_INPUT;  

// OUTPUT
wire DONE_ENABLE;
reg  HASH_DONE;
reg  K_OUT_EN;
reg  [31:0] K_OUT_PRE;  

// Data
wire [31:0] C1 [0:7];
wire [31:0] M [0:7];
wire [31:0] MESSAGE [0:25];
wire [31:0] M_REORDERED;
wire [31:0] C0_REORDERED;
wire [31:0] C1_INIT; wire [31:0] C1_REGULAR; wire [31:0] C1_COMP;  



// Description ///////////////////////////////////////////////////////////////////

    generate
        for(genvar i = 0; i < 8; i = i+1) begin
            assign C1[i] = C1_L[(i+1)*32-1:i*32];
            assign M[i]  = M_L[(i+1)*32-1:i*32];
        end
    endgenerate

    // L OUT ---------------------------------------------------------------------
    always @(*) begin
        case(CNT_ABSORB_OUT[2:0])
            3'b 000 : K_OUT_PRE = HASH_IN[255:224];
            3'b 001 : K_OUT_PRE = HASH_IN[223:192];
            3'b 010 : K_OUT_PRE = HASH_IN[191:160];
            3'b 011 : K_OUT_PRE = HASH_IN[159:128];
            3'b 100 : K_OUT_PRE = HASH_IN[127:96];
            3'b 101 : K_OUT_PRE = HASH_IN[95:64];
            3'b 110 : K_OUT_PRE = HASH_IN[63:32];
            3'b 111 : K_OUT_PRE = HASH_IN[31:0];
            default : K_OUT_PRE = {32{1'b0}};
     endcase
    end
    
    assign K_VALID = K_OUT_EN;
    assign K_OUT   = K_OUT_EN == 1'b 1 ? K_OUT_PRE : {32{1'b0}};
    assign K_ADDR  = K_OUT_EN == 1'b 1 ? CNT_ABSORB_OUT[2:0] : {3{1'b0}};
    //----------------------------------------------------------------------------
  
    // MESSAGE OUT ---------------------------------------------------------------
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
    
    assign HASH_M_OUT = (CNT_BYTES_OUT < PAD_ADDR_START) ? HASH_M : M_PADDED;
  
    // PADDING
    generate 
        if (PAD_ADDR_START == PAD_ADDR_END) begin: G0
            if (PAD_BYTE_START == 3) begin: G00
                assign M_PADDED = {1'b1, {3{1'b0}}, 3'b110, HASH_M[23:0]};
            end
            
            if (PAD_BYTE_START == 2) begin: G01
                assign M_PADDED = {1'b1, {11{1'b0}}, 3'b110, HASH_M[15:0]};
            end
        
            if (PAD_BYTE_START == 1) begin: G02
                assign M_PADDED = {1'b1, {19{1'b0}}, 3'b110, HASH_M[7:0]};
            end
        
            if (PAD_BYTE_START == 0) begin: G03
                assign M_PADDED = {1'b1, {27{1'b0}}, 3'b110};
            end
        end
    endgenerate
  
  
    generate 
        if (PAD_ADDR_START != PAD_ADDR_END) begin: G1
            if (PAD_BYTE_START == 3) begin: G10
                assign M_PADDED_PRE_START = {{4{1'b0}}, 3'b110, HASH_M[23:0]};
            end
        
            if (PAD_BYTE_START == 2) begin: G11
                assign M_PADDED_PRE_START = {{12{1'b0}}, 3'b110, HASH_M[15:0]};
            end
        
            if (PAD_BYTE_START == 1) begin: G12
                assign M_PADDED_PRE_START = {{20{1'b0}}, 3'b110, HASH_M[7:0]};
            end
        
            if (PAD_BYTE_START == 0) begin: G13
                assign M_PADDED_PRE_START = {{28{1'b0}}, 3'b110};
            end
            
            assign M_PADDED = (CNT_BYTES_OUT == PAD_ADDR_START) ? M_PADDED_PRE_START : ((CNT_BYTES_OUT == ABSORBED_WORDS) ? {1'b1, {31{1'b0}}} : {32{1'b0}});
        end
    endgenerate
    //----------------------------------------------------------------------------
  
    // DATA REORDERING AND CONCATENATION -----------------------------------------
    // read c0 from BRAM
    assign C0_ADDR = CNT_ADDR_OUT;
    assign C0_RDEN = CNT_ADDR_EN;
    assign C0_REORDERED = C0;
    
    // determine the concatenation of c0 and c1
    generate 
        if (NUM_LOWER_BYTES == 1) begin: C1_INIT00
            assign C1_INIT    = {C1[0][15:8],C1[0][23:16],C1[0][31:24],C0_REORDERED[7:0]};
            assign C1_REGULAR = {C1[CNT_REG_OUT+1][15:8], C1[CNT_REG_OUT+1][23:16], C1[CNT_REG_OUT+1][31:24], C1[CNT_REG_OUT][7:0]};
        end
    endgenerate
    generate 
        if (NUM_LOWER_BYTES == 2) begin: C1_INIT01
            assign C1_INIT = {C1[0][23:16],C1[0][31:24],C0_REORDERED[15:0]};
            assign C1_REGULAR = {C1[CNT_REG_OUT+1][23:16], C1[CNT_REG_OUT+1][31:24], C1[CNT_REG_OUT][7:0], C1[CNT_REG_OUT][15:8]};
        end
    endgenerate
    generate 
        if (NUM_LOWER_BYTES == 3) begin: C1_INIT02
            assign C1_INIT = {C1[0][31:24],C0_REORDERED[23:0]};
//            assign C1_REGULAR = {C1[CNT_REG_OUT+1][31:24], C1[CNT_REG_OUT][23:0]};
            assign C1_REGULAR = {C1[CNT_REG_OUT+1][31:24], C1[CNT_REG_OUT][7:0], C1[CNT_REG_OUT][15:8], C1[CNT_REG_OUT][23:16]};
        end
    endgenerate
    generate 
        if (NUM_LOWER_BYTES == 4) begin: C1_INIT03
            assign C1_INIT = C0_REORDERED[31:0];
            assign C1_REGULAR = {C1[CNT_REG_OUT][7:0], C1[CNT_REG_OUT][15:8], C1[CNT_REG_OUT][23:16], C1[CNT_REG_OUT][31:24]};
        end
    endgenerate
  
    assign C1_COMP = (CNT_BYTES_OUT == (DWORDS + 8)) ? C1_INIT : C1_REGULAR;
    
    // reordering m
    assign M_REORDERED = {M[CNT_REG_OUT][7:0], M[CNT_REG_OUT][15:8], M[CNT_REG_OUT][23:16], M[CNT_REG_OUT][31:24]};
    
    // determine the correct data
    always @(*) begin
        case(SEL_HASH_INPUT)
            3'b 001 : HASH_M = M_REORDERED;
            3'b 010 : HASH_M = C0_REORDERED;
            3'b 100 : HASH_M = C1_COMP;
            default : HASH_M = {32{1'b0}};
        endcase
    end

    always @(CNT_BYTES_OUT) begin
        if(((CNT_BYTES_OUT)) <= 8) begin
            SEL_HASH_INPUT = 3'b001;
        end
        else if(CNT_BYTES_OUT < (8 + DWORDS)) begin
            SEL_HASH_INPUT = 3'b010;
        end
        else begin
            SEL_HASH_INPUT = 3'b100;
        end
    end
    //----------------------------------------------------------------------------
    
    // DONE ----------------------------------------------------------------------
    assign DONE_ENABLE = CNT_BYTES_DONE;
    
    always @(posedge CLK) begin
        if(~RESETN) begin
            HASH_DONE <= 1'b0;
        end
        else begin
            if(DONE_ENABLE) begin
                HASH_DONE <= 1'b1;
            end
        end
    end
    //----------------------------------------------------------------------------
    
    // COUNTER -------------------------------------------------------------------
    always @(posedge CLK) begin
        CNT_REG_EN <= CNT_REG_EN_D;
    end
    
    assign CNT_REG_EN_D = SEL_HASH_INPUT == 3'b001 || SEL_HASH_INPUT == 3'b100 ? 1'b1 & CNT_BYTES_EN : 1'b0;
    assign CNT_REG_RSTN = (RESETN == 1'b0) ? RESETN : (SEL_HASH_INPUT == 3'b001 || SEL_HASH_INPUT == 3'b100) ? 1'b1 : 1'b0;
    BIKE_counter_inc_stop #(.SIZE(int'($clog2(256/32))), .MAX_VALUE(256/32))
    reg_cnt (.clk(CLK), .enable(CNT_REG_EN), .resetn(CNT_REG_RSTN), .cnt_out(CNT_REG_OUT));

    assign CNT_ADDR_EN = (CNT_BYTES_EN == 1'b1 && CNT_BYTES_OUT >= 8) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(LOGDWORDS), .MAX_VALUE(DWORDS-1))
    cnt_addr (.clk(CLK), .enable(CNT_ADDR_EN), .resetn(CNT_ADDR_RSTN), .cnt_out(CNT_ADDR_OUT));

    assign CNT_ABSORB_DONE = (CNT_ABSORB_OUT == (832/32-3)) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(832/32))), .MAX_VALUE(int'(832/32-1)))
    cnt_absorb (.clk(CLK), .enable(CNT_ABSORB_EN), .resetn(CNT_ABSORB_RSTN), .cnt_out(CNT_ABSORB_OUT));

    assign CNT_BYTES_DONE = (CNT_BYTES_OUT == (ABSORBED_WORDS-1)) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(ABSORBED_WORDS))), .MAX_VALUE(ABSORBED_WORDS))
    cnt_bytes (.clk(CLK), .enable(CNT_BYTES_EN), .resetn(CNT_BYTES_RSTN), .cnt_out(CNT_BYTES_OUT));     
    //----------------------------------------------------------------------------
  
    // FINITE STATE MACHINE ------------------------------------------------------
    always @(posedge CLK) begin
        // GLOBAL -----------------
        DONE                <= 1'b0;
        
        // COUNTER ----------------
        CNT_ADDR_RSTN       <= 1'b0;
        CNT_ABSORB_RSTN     <= 1'b0;
        CNT_ABSORB_EN       <= 1'b0;
        CNT_BYTES_RSTN      <= 1'b0;
        CNT_BYTES_EN        <= 1'b0;
        
        // KECCAK -----------------
        KECCAK_INIT         <= 1'b0;
        KECCAK_EN           <= 1'b0;
        
        // INTERNAL ---------------
        K_OUT_EN            <= 1'b0;
        
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
                CNT_ADDR_RSTN       <= 1'b1;
                CNT_BYTES_EN        <= 1'b1;
                CNT_BYTES_RSTN      <= 1'b1;
                
                // TRANSITION ------
                STATE               <= S_ABSORB;
            end
            //--------------------------------------------	
            
            //--------------------------------------------
            S_ABSORB : begin
                // COUNTER ---------
                CNT_ADDR_RSTN       <= 1'b1;
                CNT_BYTES_EN        <= 1'b1;
                CNT_ABSORB_RSTN     <= 1'b1;
                CNT_ABSORB_EN       <= 1'b1;
                CNT_BYTES_RSTN      <= 1'b1;
                
                // KECCAK ----------
                KECCAK_INIT         <= 1'b1;
                
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
                CNT_ADDR_RSTN       <= 1'b1;
                CNT_ABSORB_RSTN     <= 1'b1;
                CNT_ABSORB_EN       <= 1'b1;
                CNT_BYTES_RSTN      <= 1'b1;
                
                // KECCAK ----------
                KECCAK_INIT         <= 1'b1;
                
                // TRANSITION ------
                STATE               <= S_ENABLE_KECCAK;
            end
            //--------------------------------------------	
            
            //--------------------------------------------

            S_ENABLE_KECCAK : begin
                // COUNTER ---------
                CNT_ADDR_RSTN       <= 1'b1;
                CNT_BYTES_RSTN      <= 1'b1;
                
                // KECCAK ----------
                KECCAK_EN           <= 1'b1;
                
                // TRANSITION ------
                STATE               <= S_WAIT;
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_WAIT : begin
                // COUNTER ---------
                CNT_ADDR_RSTN       <= 1'b1;
                CNT_BYTES_RSTN      <= 1'b1;
                
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
                CNT_ABSORB_RSTN     <= 1'b1;
                CNT_ABSORB_EN       <= 1'b1;
                
                // INTERNAL --------
                K_OUT_EN            <= 1'b1;
                
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
                DONE                <= 1'b1;
                
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
