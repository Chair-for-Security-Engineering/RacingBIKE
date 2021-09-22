`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         22.02.2021 
// Module Name:         BIKE_bfiter_generic
// Description:         BGF Decoder - can be used fora ll memory types (not optimized for Xilinx FPGAs).
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

module BIKE_bfiter_generic(
    input  wire CLK,
    // Control ports
    input  wire RESETN,
    input  wire ENABLE,
    output reg  DONE,
    input  wire [1:0] MODE_SEL, // "00" Produce black/gray lists; "01" use black mask; "10" use gray mask; "11" only error flip
    // Threshold
    input  wire [int'($clog2(W/2))-1:0] TH,
    // Syndrome
    output reg  SYNDROME_RDEN,
    output reg  SYNDROME_WREN,
    output wire [LOGSWORDS-1:0] SYNDROME_A_ADDR,
    output wire [B_WIDTH-1:0] SYNDROME_A_DOUT,
    input  wire [B_WIDTH-1:0] SYNDROME_A_DIN,
    output wire [LOGSWORDS-1:0] SYNDROME_B_ADDR,
    output wire [B_WIDTH-1:0] SYNDROME_B_DOUT,
    input  wire [B_WIDTH-1:0] SYNDROME_B_DIN,
    // Secret Key
    output wire SK0_RDEN,
    output wire SK1_RDEN,
    output wire SK0_WREN,
    output wire SK1_WREN,
    output wire [LOGDWORDS-1:0] SK_ADDR,
    output wire [31:0] SK_DOUT,
    input  wire [31:0] SK0_DIN,
    input  wire [31:0] SK1_DIN,
    // Error
    output wire E0_RDEN,
    output wire E1_RDEN,
    output wire E0_WREN,
    output wire E1_WREN,
    output wire [LOGSWORDS-1:0] E_ADDR,
    output wire [B_WIDTH-1:0] E_DOUT,
    input  wire [B_WIDTH-1:0] E0_DIN,
    input  wire [B_WIDTH-1:0] E1_DIN,
    // Black
    output wire BLACK0_RDEN,
    output wire BLACK1_RDEN,
    output wire BLACK0_WREN,
    output wire BLACK1_WREN,
    output wire [LOGSWORDS-1:0] BLACK_ADDR,
    output wire [B_WIDTH-1:0] BLACK_DOUT,
    input  wire [B_WIDTH-1:0] BLACK0_DIN,
    input  wire [B_WIDTH-1:0] BLACK1_DIN,
    // Gray
    output wire GRAY0_RDEN,
    output wire GRAY1_RDEN,
    output wire GRAY0_WREN,
    output wire GRAY1_WREN,
    output wire [LOGSWORDS-1:0] GRAY_ADDR,
    output wire [B_WIDTH-1:0] GRAY_DOUT,
    input  wire [B_WIDTH-1:0] GRAY0_DIN,
    input  wire [B_WIDTH-1:0] GRAY1_DIN
);



// Wires and Registers
// Counter
wire CNT_CTR_DONE;
reg  CNT_CTR_RSTN; reg CNT_CTR_EN;
wire [int'($clog2(W/2))-1:0] CNT_CTR_OUT;

reg  CNT_UPC_RSTN;
wire [B_WIDTH-1:0] CNT_UPC_EN;  
wire [int'($clog2(W/2))-1:0] CNT_UPC_OUT [0:B_WIDTH-1];

wire CNT_NCOL_DONE;
reg  CNT_COL_RSTN; reg CNT_COL_EN;
wire [int'($clog2(2*SWORDS))-1:0] CNT_NCOL_OUT;
wire [LOGRBITS-1:0] CNT_RCOL_OUT;
wire [LOGSWORDS-1:0] CNT_ERROR_OUT;  

// Control
reg CNT_UPC_VALID;
wire SECOND_POLY;
wire ADJUST_SYNDROME;  

// SK
wire [LOGRBITS-1:0] SK_ROW;
wire [15:0] SK_ROW_HI;
wire [LOGRBITS-1:0] SK_ROW_PRE;
wire [LOGRBITS:0] ROW_DEC; 
wire [LOGRBITS:0] ROW_RED; 
wire [LOGRBITS:0] ROW_FIN;
wire [LOGBWIDTH:0] SK_ROW_ADD; 
wire [LOGBWIDTH:0] SK_BIT;
reg  SK_RDEN; reg SK_WREN;
wire READ_FROM_MSB_IN;
reg  READ_FROM_MSB;  

// SYNDROME
reg SYNDROME_INIT_RD;
reg SYNDROME_INIT_WR;
wire [LOGSWORDS-1:0] SYNDROME_ADDR_HIGH;
wire [2 * B_WIDTH - 1:0] SYNDROME_DIN;  

// Error
wire [B_WIDTH-1:0] NEW_E_VEC; 
wire [B_WIDTH-1:0] NEW_GRAY_VEC;
reg E_RDEN; 
reg E_WREN;
wire [B_WIDTH-1:0] E_DOUT_FLIP; wire [B_WIDTH - 1:0] E_DOUT_BG;
wire [B_WIDTH-1:0] E_DOUT_PRE;
wire [B_WIDTH-1:0] E0_XOR_BIT; wire [B_WIDTH - 1:0] E1_XOR_BIT;
wire [B_WIDTH-1:0] E_XOR_BIT; wire [B_WIDTH - 1:0] E_IN;  

// Black/Gray
wire [B_WIDTH-1:0] BLACK_NEW; 
wire [B_WIDTH-1:0] GRAY_NEW;
wire [B_WIDTH-1:0] BLACK_CHUNK;
wire [B_WIDTH-1:0] GRAY_CHUNK;
reg  [B_WIDTH-1:0] MASK;
wire [B_WIDTH-1:0] BLACK_DIN; 
wire [B_WIDTH-1:0] GRAY_DIN;
reg  GRAY_RDEN; 
reg  GRAY_WREN;  

// STATES
parameter [3:0]
  S_RESET               = 0,
  S_INIT0               = 1,
  S_INIT1               = 2,
  S_CTR_READ_SK_INIT    = 3,
  S_CTR_READ_SK         = 4,
  S_CTR_READ_S          = 5,
  S_CTR_READ_S_READ     = 6,
  S_CTR_READ_LAST_S     = 7,
  S_CTR_READ_LAST_S2    = 8,
  S_CHECK_TH            = 9,
  S_ERROR_READ          = 10,
  S_ERROR_WRITE         = 11,
  S_DONE                = 12;

reg [3:0] STATE = S_RESET;  


// Description

    // Counter ///////////////////////////////////////////////////////////////////
    // used to read the secret key
    assign CNT_CTR_DONE = (CNT_CTR_OUT == (W/2-1)) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(W/2))), .MAX_VALUE(W/2-1))
    cnt_ctr (.clk(CLK), .resetn(CNT_CTR_RSTN), .enable(CNT_CTR_EN), .cnt_out(CNT_CTR_OUT));
    
    // count the unsatisfied parity check equations
    generate
        for(genvar i=0; i<B_WIDTH; i=i+1) begin
            BIKE_counter_inc #(.SIZE(int'($clog2(W/2))), .MAX_VALUE(W/2))
            cnt_upc (.clk(CLK), .resetn(CNT_UPC_RSTN), .enable(CNT_UPC_EN[i]), .cnt_out(CNT_UPC_OUT[i]));
        end
    endgenerate 
    
    // indicates whether the computation is in the first polynomial or in the second
    assign SECOND_POLY = (CNT_NCOL_OUT >= SWORDS) ? 1'b1 : 1'b0;
    
    // counts the total number of columns already checked
    assign CNT_NCOL_DONE = (CNT_NCOL_OUT == 2*SWORDS-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(2*SWORDS-1))), .MAX_VALUE(2*SWORDS))
    cnt_ncol (.clk(CLK), .resetn(CNT_COL_RSTN), .enable(CNT_COL_EN), .cnt_out(CNT_NCOL_OUT));
    
    // counter for the error polynomial
    BIKE_counter_inc #(.SIZE(LOGSWORDS), .MAX_VALUE(SWORDS-1))
    cnt_error(.clk(CLK), .resetn(CNT_COL_RSTN), .enable(CNT_COL_EN), .cnt_out(CNT_ERROR_OUT));
    //////////////////////////////////////////////////////////////////////////////
    

    // addresses
    assign SK_ADDR = {{(LOGDWORDS-int'($clog2(W/2))){1'b0}}, CNT_CTR_OUT};
    
    // we need 2*B_WIDTH bit of the syndrome
    assign SYNDROME_A_ADDR      = ((SYNDROME_INIT_RD == 1'b1) | (SYNDROME_INIT_WR == 1'b1)) ? SWORDS-1 : SK_ROW[LOGSWORDS-1+LOGBWIDTH:LOGBWIDTH]; 
    assign SYNDROME_ADDR_HIGH   = SK_ROW[LOGSWORDS-1+LOGBWIDTH:LOGBWIDTH] + 1'b1;
    assign SYNDROME_B_ADDR      = (SYNDROME_INIT_RD == 1'b1) ? {LOGSWORDS{1'b0}} : ((SYNDROME_INIT_WR == 1'b1) ? SWORDS-1 : ((SYNDROME_ADDR_HIGH == SWORDS) ? {LOGSWORDS{1'b0}} : SYNDROME_ADDR_HIGH));
  
    // just needed in the initial phase to copy the LSBs to the most significant chunk of the syndrome polynomials
    // As an example for R_BITS=59 and B_WIDTH=8:
    // |0 0 0 0 0 s58 s57 s56 | ... | ... | s7 s6 s5 s4 s3 s2 s1 s0 | -> |s4 s3 s2 s1 s0 s58 s57 s56 | ... | ... | s7 s6 s5 s4 s3 s2 s1 s0 |
    assign SYNDROME_A_DOUT      = {SYNDROME_B_DIN[B_WIDTH - OVERHANG - 1:0],SYNDROME_A_DIN[OVERHANG - 1:0]};
    assign SYNDROME_B_DOUT      = {SYNDROME_B_DIN[B_WIDTH - OVERHANG - 1:0],SYNDROME_A_DIN[OVERHANG - 1:0]};
    
    assign READ_FROM_MSB_IN     = (SK_ROW[LOGSWORDS-1+LOGBWIDTH:LOGBWIDTH] == (SWORDS-1)) ? 1'b1 : 1'b0;
    always @(posedge CLK) begin
        if(~RESETN) begin   
            READ_FROM_MSB <= 1'b0;
        end
        else begin 
            if(ENABLE) begin    
                READ_FROM_MSB <= READ_FROM_MSB_IN;
            end else begin
                READ_FROM_MSB <= READ_FROM_MSB;
            end
        end
    end

    // count when the corresponing bit in the syndrome is set
    assign SYNDROME_DIN = (READ_FROM_MSB == 1'b1) ? {{(2*B_WIDTH-OVERHANG-B_WIDTH){1'b0}}, SYNDROME_B_DIN, SYNDROME_A_DIN[OVERHANG-1:0]} : {SYNDROME_B_DIN, SYNDROME_A_DIN};

    generate 
        for (genvar i=0; i < B_WIDTH; i=i+1) begin
            assign CNT_UPC_EN[i] = ((SYNDROME_DIN[SK_BIT+i] == 1'b1) & (CNT_UPC_VALID == 1'b1)) ? 1'b1 : 1'b0;
        end
    endgenerate
  
    assign SK_ROW       = (SECOND_POLY == 1'b0) ? SK0_DIN[LOGRBITS-1:0] : SK1_DIN[LOGRBITS-1:0];
    assign SK_ROW_HI    = (SECOND_POLY == 1'b0) ? SK0_DIN[31:16] : SK1_DIN[31:16];
  
    assign SK_ROW_ADD   = {1'b0, SK_ROW[LOGBWIDTH-1:0]};
    
    RegisterFDRE #(.SIZE(LOGBWIDTH+1))
    sk_reg (.clk(CLK), .enable(ENABLE), .resetn(RESETN), .d(SK_ROW_ADD), .q(SK_BIT));
  
    // outputs for secret key
    assign SK0_RDEN = (SECOND_POLY == 1'b0) ? SK_RDEN : 1'b0;
    assign SK1_RDEN = (SECOND_POLY == 1'b1) ? SK_RDEN : 1'b0;
    assign SK0_WREN = (SECOND_POLY == 1'b0) ? SK_WREN : 1'b0;
    assign SK1_WREN = (SECOND_POLY == 1'b1) ? SK_WREN : 1'b0;
    
    // increase key by B_WIDTH for the next iteration
    assign ROW_DEC = SK_ROW + B_WIDTH;
    assign ROW_RED = ROW_DEC - R_BITS;
    assign ROW_FIN = (ROW_RED[LOGRBITS] == 1'b1) ? ROW_DEC : ROW_RED;
  
    // if we are checking the last chunk of a polynomial, we have to reset the key to the original one
    // when reading and storing the key, we duplicate it and store it the bits 31:16 - working bits are 15:0
    assign SK_DOUT = ((CNT_NCOL_OUT == (SWORDS-1)) | (CNT_NCOL_DONE == 1'b1)) ? {SK_ROW_HI, SK_ROW_HI} : {SK_ROW_HI, {(16-LOGRBITS){1'b0}}, ROW_FIN[LOGRBITS-1:0]};
    //----------------------------------------------------------------------------
  
    // FLIP ERROR ----------------------------------------------------------------
    assign E0_RDEN = SECOND_POLY == 1'b 0 ? E_RDEN : 1'b 0;
    assign E1_RDEN = SECOND_POLY == 1'b 1 ? E_RDEN : 1'b 0;
    assign E0_WREN = SECOND_POLY == 1'b 0 ? E_WREN : 1'b 0;
    assign E1_WREN = SECOND_POLY == 1'b 1 ? E_WREN : 1'b 0;
    assign E_ADDR = CNT_ERROR_OUT;
  
    // ERROR OUT - SPECIAL CASE FOR MOST SIGNIFICANT CHUNK -----------------------
    assign E_DOUT_PRE   = MODE_SEL == 2'b 00 || MODE_SEL == 2'b 11 ? E_DOUT_FLIP : E_DOUT_BG;
    assign E_DOUT       = (CNT_ERROR_OUT == (SWORDS-1)) ? {{(B_WIDTH-OVERHANG){1'b0}}, E_DOUT_PRE[OVERHANG-1:0]} : E_DOUT_PRE; 

    assign E_IN = SECOND_POLY == 1'b 0 ? E0_DIN : E1_DIN;
    assign E_XOR_BIT = E_IN ^ NEW_E_VEC;
    assign E_DOUT_FLIP = E_XOR_BIT;
  
    generate 
        for (genvar i=0; i < B_WIDTH; i=i+1) begin
            assign E_DOUT_BG[i] = (MASK[i] == 1'b1) ? E_XOR_BIT[i] : E_IN[i];
        end
    endgenerate 
    
    // select black/gray mask
    always @(*) begin
        case(MODE_SEL)
            2'b01   : MASK <= BLACK_DIN;
            2'b10   : MASK <= GRAY_DIN;
            default : MASK <= {(((B_WIDTH - 1))-((0))+1){1'b0}};
        endcase
    end 

    // determine new chunk for error vector
    generate 
        for (genvar i=0; i < B_WIDTH; i=i+1) begin
            assign NEW_E_VEC[i]     = (CNT_UPC_OUT[i] >= TH) ? 1'b1 : 1'b0;
            assign NEW_GRAY_VEC[i]  = (CNT_UPC_OUT[i] >= (TH - TAU) && (CNT_UPC_OUT[i] < TH)) ? 1'b1 : 1'b0;
        end
    endgenerate

    // BLACK LIST
    assign BLACK0_RDEN  = ((SECOND_POLY == 1'b0) && (MODE_SEL == 2'b00 || MODE_SEL == 2'b01)) ? E_RDEN : 1'b0;
    assign BLACK1_RDEN  = ((SECOND_POLY == 1'b1) && (MODE_SEL == 2'b00 || MODE_SEL == 2'b01)) ? E_RDEN : 1'b0;
    
    assign BLACK0_WREN  = ((SECOND_POLY == 1'b0) && (MODE_SEL == 2'b00)) ? E_WREN : 1'b0;
    assign BLACK1_WREN  = ((SECOND_POLY == 1'b1) && (MODE_SEL == 2'b00)) ? E_WREN : 1'b0;
    
    assign BLACK_ADDR   = CNT_ERROR_OUT;
    assign BLACK_DOUT   = (MODE_SEL == 2'b00) ? NEW_E_VEC : {B_WIDTH{1'b0}};
    assign BLACK_DIN    = (SECOND_POLY == 1'b0) ? BLACK0_DIN : BLACK1_DIN;
  
    // GRAY LIST
    assign GRAY0_RDEN   = ((SECOND_POLY == 1'b0) && (MODE_SEL == 2'b00)) ? E_RDEN : ((SECOND_POLY == 1'b0) && (MODE_SEL == 2'b10)) ? E_RDEN : 1'b0;
    assign GRAY1_RDEN   = ((SECOND_POLY == 1'b1) && (MODE_SEL == 2'b00)) ? E_RDEN : ((SECOND_POLY == 1'b1) && (MODE_SEL == 2'b10)) ? E_RDEN : 1'b0;
    
    assign GRAY0_WREN   = ((SECOND_POLY == 1'b0) && (MODE_SEL == 2'b00)) ? E_WREN : 1'b0;
    assign GRAY1_WREN   = ((SECOND_POLY == 1'b1) && (MODE_SEL == 2'b00)) ? E_WREN : 1'b0;
    
    assign GRAY_ADDR    = CNT_ERROR_OUT;
    assign GRAY_DOUT    = (MODE_SEL == 2'b00) ? NEW_GRAY_VEC : {B_WIDTH{1'b0}};
    assign GRAY_DIN     = (SECOND_POLY == 1'b0) ? GRAY0_DIN : GRAY1_DIN;
    //----------------------------------------------------------------------------
  
    // FSM -----------------------------------------------------------------------
    always @(posedge CLK) begin
        // GLOBAL ----------
        DONE                <= 1'b0;
        
        // COUNTER ---------
        CNT_CTR_RSTN        <= 1'b0;
        CNT_CTR_EN          <= 1'b0;
        CNT_UPC_RSTN        <= 1'b0;
        CNT_COL_RSTN        <= 1'b0;
        CNT_COL_EN          <= 1'b0;
        
        // CONTROL ---------
        CNT_UPC_VALID       <= 1'b0;
        
        // SYNDROM ---------
        SYNDROME_RDEN       <= 1'b0;
        SYNDROME_WREN       <= 1'b0;
        SYNDROME_INIT_RD    <= 1'b0;
        SYNDROME_INIT_WR    <= 1'b0;
        
        // SECRET KEY ------  
        SK_RDEN             <= 1'b0;
        SK_WREN             <= 1'b0;
        
        // ERROR -----------
        E_RDEN              <= 1'b0;
        E_WREN              <= 1'b0;
        
        // GRAY ------------
        GRAY_RDEN           <= 1'b0;
        GRAY_WREN           <= 1'b0;
        
        if(~RESETN) begin
            STATE <= S_RESET;
        end
        else begin
            case(STATE)
                //--------------------------------------------
                S_RESET : begin
                    // TRANSITION ------
                    if(ENABLE) begin
                        STATE               <= S_INIT0;
                    end
                    else begin
                        STATE               <= S_RESET;
                    end
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_INIT0 : begin
                    // SYNDROM ---------
                    SYNDROME_RDEN           <= 1'b1;
                    SYNDROME_INIT_RD        <= 1'b1;
                    
                    // TRANSITION ------
                    STATE                   <= S_INIT1;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_INIT1 : begin
                    // SYNDROM ---------
                    SYNDROME_RDEN           <= 1'b1;
                    SYNDROME_WREN           <= 1'b1;
                    SYNDROME_INIT_WR        <= 1'b1;
                    
                    // TRANSITION ------
                    STATE                   <= S_CTR_READ_SK_INIT;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_CTR_READ_SK_INIT : begin
                    // COUNTER ---------
                    CNT_CTR_RSTN            <= 1'b1;
                    CNT_CTR_EN              <= 1'b1;
                    CNT_UPC_RSTN            <= 1'b0;
                    CNT_COL_RSTN            <= 1'b1;
                    
                    // SECRET KEY ------  
                    SK_RDEN                 <= 1'b1;
                    SK_WREN                 <= 1'b0;
                    
                    // TRANSITION ------
                    if(CNT_NCOL_DONE) begin
                        STATE               <= S_DONE;
                    end
                    else begin
                        STATE               <= S_CTR_READ_SK;
                    end
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_CTR_READ_SK : begin
                    // COUNTER ---------
                    CNT_CTR_RSTN            <= 1'b1;
                    CNT_CTR_EN              <= 1'b1;
                    CNT_UPC_RSTN            <= 1'b1;
                    CNT_COL_RSTN            <= 1'b1;
                    
                    // SYNDROM ---------
                    SYNDROME_RDEN           <= 1'b1;
                    
                    // SECRET KEY ------  
                    SK_RDEN                 <= 1'b1;
                    SK_WREN                 <= 1'b1;
                    
                    // TRANSITION ------
                    STATE                   <= S_CTR_READ_S;
                end
                //--------------------------------------------

//                //--------------------------------------------
//                S_CTR_READ_S_READ : begin
//                    // COUNTER ---------
//                    CNT_CTR_RSTN            <= 1'b1;
//                    CNT_CTR_EN              <= 1'b0;
//                    CNT_UPC_RSTN            <= 1'b1;
//                    CNT_COL_RSTN            <= 1'b1;
                    
//                    // CONTROL ---------
//                    CNT_UPC_VALID           <= 1'b1;
                    
//                    // SYNDROM ---------
//                    SYNDROME_RDEN           <= 1'b1;
                    
//                    // SECRET KEY ------  
//                    SK_RDEN                 <= 1'b1;
//                    SK_WREN                 <= 1'b0;
                    
//                    // TRANSITION ------
//                    STATE                   <= S_CTR_READ_S;
//                end
//                //--------------------------------------------
                                
                //--------------------------------------------
                S_CTR_READ_S : begin
                    // COUNTER ---------
                    CNT_CTR_RSTN            <= 1'b1;
                    CNT_CTR_EN              <= 1'b1;
                    CNT_UPC_RSTN            <= 1'b1;
                    CNT_COL_RSTN            <= 1'b1;
                    
                    // CONTROL ---------
                    CNT_UPC_VALID           <= 1'b1;
                    
                    // SYNDROM ---------
                    SYNDROME_RDEN           <= 1'b1;
                    
                    // SECRET KEY ------  
                    SK_RDEN                 <= 1'b1;
                    SK_WREN                 <= 1'b1;
                    
                    // TRANSITION ------
                    if(CNT_CTR_DONE) begin
                        STATE               <= S_CTR_READ_LAST_S;
                    end
                    else begin
                        STATE               <= S_CTR_READ_S;
                    end
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_CTR_READ_LAST_S : begin
                    // COUNTER ---------
                    CNT_UPC_RSTN            <= 1'b1;
                    CNT_COL_RSTN            <= 1'b1;
                    
                    // CONTROL ---------
                    CNT_UPC_VALID           <= 1'b1;
                    
                    // SYNDROM ---------
                    SYNDROME_RDEN           <= 1'b1;
                    
                    // TRANSITION ------
                    STATE                   <= S_CTR_READ_LAST_S2;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_CTR_READ_LAST_S2 : begin
                    // COUNTER ---------
                    CNT_UPC_RSTN            <= 1'b1;
                    CNT_COL_RSTN            <= 1'b1;
                    
                    // SYNDROM ---------
                    SYNDROME_RDEN           <= 1'b0;
                    
                    // TRANSITION ------
                    STATE                   <= S_CHECK_TH;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_CHECK_TH : begin
                    // GLOBAL ----------
                    DONE                    <= 1'b0;
                    
                    // COUNTER ---------    
                    CNT_UPC_RSTN            <= 1'b1;
                    CNT_COL_RSTN            <= 1'b1;
                    
                    // TRANSITION ------    
                    STATE                   <= S_ERROR_READ;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_ERROR_READ : begin
                    // COUNTER ---------
                    CNT_COL_RSTN            <= 1'b1;
                    CNT_COL_EN              <= 1'b0;
                    
                    // CONTROL ---------
                    CNT_UPC_VALID           <= 1'b0;
                    
                    // COUNTER ---------    
                    CNT_UPC_RSTN            <= 1'b1;
                    
                    // ERROR -----------
                    E_RDEN                  <= 1'b1;
                    E_WREN                  <= 1'b0;
                    
                    // TRANSITION ------
                    STATE                   <= S_ERROR_WRITE;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_ERROR_WRITE : begin
                    // COUNTER ---------
                    CNT_COL_RSTN            <= 1'b1;
                    CNT_COL_EN              <= 1'b1;
                    
                    // ERROR -----------
                    E_RDEN                  <= 1'b1;
                    E_WREN                  <= 1'b1;
                    
                    // COUNTER ---------    
                    CNT_UPC_RSTN            <= 1'b1;
                    
                    // TRANSITION ------
                    STATE                   <= S_CTR_READ_SK_INIT;
                end
                //--------------------------------------------
                
                //--------------------------------------------
                S_DONE : begin
                    // GLOBAL ----------
                    DONE                    <= 1'b1;
                    
                    // TRANSITION ------
                    STATE                   <= S_RESET;
                end
                //--------------------------------------------
            endcase
        end
    end 

    //----------------------------------------------------------------------------

endmodule
