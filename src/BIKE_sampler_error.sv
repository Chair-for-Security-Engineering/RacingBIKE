//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         12.01.2021 
// Module Name:         BIKE_SAMPLER_ERROR
// Description:         Is used to sample the error vector (H-Function). Paritally translated with vhd2vl.
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

module BIKE_sampler_error
    #(  
        parameter THRESHOLD = 10
    )(
        input wire CLK,
        input wire RESETN,
        input wire ENABLE,
        output reg DONE,
        input wire [255:0] KECCAK_SEED,
        output reg KECCAK_ENABLE,
        output reg KECCAK_INIT,
        input wire KECCAK_DONE,
        output wire [STATE_WIDTH-1:0] KECCAK_M,
        input wire [STATE_WIDTH-1:0] KECCAK_OUT,
        output wire RDEN_1,
        output wire WREN_1,
        output wire RDEN_2,
        output wire WREN_2,
        output wire [LOGDWORDS-1:0] ADDR,
        output wire [31:0] DOUT,
        output wire [31:0] DIN_1,
        output wire [31:0] DIN_2,
        // compact representation
        output wire e_compact_rden,
        output wire e_compact_wren,
        output wire [LOGDWORDS-1:0] e_compact_addr,
        output wire [31:0] e_compact_dout        
);

//input  CLK;
//// CONTROL PORTS ---------------	
//input  RESETN;
//input  ENABLE;
//output DONE;
//// RAND ------------------------
//input  [255:0] KECCAK_SEED;
//output KECCAK_ENABLE;
//output KECCAK_INIT;
//input  KECCAK_DONE;
//output [STATE_WIDTH - 1:0] KECCAK_M;
//input  [STATE_WIDTH - 1:0] KECCAK_OUT;
//// MEMORY I/O ------------------
//output RDEN_1;
//output WREN_1;
//output RDEN_2;
//output WREN_2;
//output [LOGDWORDS-1:0] ADDR;
//output [31:0] DOUT;
//input  [31:0] DIN_1;
//input  [31:0] DIN_2;

//wire CLK;
//wire RESETN;
//wire ENABLE;
//reg  DONE;
//wire [255:0] KECCAK_SEED;
//reg  KECCAK_ENABLE;
//reg  KECCAK_INIT;
//wire KECCAK_DONE;
//wire [STATE_WIDTH - 1:0] KECCAK_M;
//wire [STATE_WIDTH - 1:0] KECCAK_OUT;
//wire RDEN_1;
//wire WREN_1;
//wire RDEN_2;
//wire WREN_2;
//wire [LOGDWORDS-1:0] ADDR;
//wire [31:0] DOUT;
//wire [31:0] DIN_1;
//wire [31:0] DIN_2;


// Parameter
parameter integer DIGIST_SIZE = 1088;


// Wires and registers ///////////////////////////////////////////////////////////
// COUNTER
reg  CNT_RESETN; 
wire CNT_ENABLE; 
reg  CNT_VALID;
wire [int'($clog2(THRESHOLD+1))-1:0] CNT_OUT;
reg  CNT_RND_RSTN; 
reg  CNT_RND_EN;
wire [5:0] CNT_RND_OUT;  

// SAMPLER
reg  [31:0] NEW_RAND;
wire [int'($clog2(N_BITS))-1:0] NEW_POSITION; 
wire [int'($clog2(N_BITS))-1:0] NEW_POSITION_DIFF;
wire [4:0] BIT_POSITION;
reg  [31:0] NEW_BIT;
wire VALID_RAND;
wire [31:0] DIN;  

// compact representation 
wire [31:0] new_position_compact;
wire [31:0] new_position_e0;
wire [31:0] new_position_e1;


// PRNG
wire [DIGIST_SIZE-1:0] RANDOMNESS;  

// FSM
reg WREN; 
reg RDEN; 
 
// STATES
parameter [2:0]
  S_RESET           = 0,
  S_KECCAK_INIT     = 1,
  S_KECCAK_INIT1    = 2,
  S_KECCAK          = 3,
  S_SAMPLE_READ     = 4,
  S_SAMPLE_WRITE    = 5,
  S_DONE            = 6;

reg [2:0] STATE = S_RESET;  



// Description ///////////////////////////////////////////////////////////////////

    // PRNG ----------------------------------------------------------------------
    // reorder seed in order to match software implementation
    generate 
        for (genvar I=0; I <= 31; I = I + 1) begin
            assign KECCAK_M[(I*8+7):(I*8)] = KECCAK_SEED[(255-I*8):(248-I*8)];
        end
    endgenerate
    
    assign KECCAK_M[260:256] = 5'b11111;
    assign KECCAK_M[DIGIST_SIZE-2:261] = 'b0;
    assign KECCAK_M[DIGIST_SIZE-1] = 1'b1;
    assign KECCAK_M[1599:DIGIST_SIZE] = {256{1'b0}};
    assign RANDOMNESS = KECCAK_OUT[STATE_WIDTH - 1:STATE_WIDTH - DIGIST_SIZE];
    
    // Random output is divided into fout 32-bit blocks of randomness    
    always @(*) begin
        case(CNT_RND_OUT)
            6'b000000 : NEW_RAND <= {RANDOMNESS[1063:1056],RANDOMNESS[1071:1064],RANDOMNESS[1079:1072],RANDOMNESS[1087:1080]};
            6'b000001 : NEW_RAND <= {RANDOMNESS[1031:1024],RANDOMNESS[1039:1032],RANDOMNESS[1047:1040],RANDOMNESS[1055:1048]};
            6'b000010 : NEW_RAND <= {RANDOMNESS[999:992],RANDOMNESS[1007:1000],RANDOMNESS[1015:1008],RANDOMNESS[1023:1016]};  
            6'b000011 : NEW_RAND <= {RANDOMNESS[967:960],RANDOMNESS[975:968],RANDOMNESS[983:976],RANDOMNESS[991:984]};        
            6'b000100 : NEW_RAND <= {RANDOMNESS[935:928],RANDOMNESS[943:936],RANDOMNESS[951:944],RANDOMNESS[959:952]};        
            6'b000101 : NEW_RAND <= {RANDOMNESS[903:896],RANDOMNESS[911:904],RANDOMNESS[919:912],RANDOMNESS[927:920]};        
            6'b000110 : NEW_RAND <= {RANDOMNESS[871:864],RANDOMNESS[879:872],RANDOMNESS[887:880],RANDOMNESS[895:888]};        
            6'b000111 : NEW_RAND <= {RANDOMNESS[839:832],RANDOMNESS[847:840],RANDOMNESS[855:848],RANDOMNESS[863:856]};        
            6'b001000 : NEW_RAND <= {RANDOMNESS[807:800],RANDOMNESS[815:808],RANDOMNESS[823:816],RANDOMNESS[831:824]};        
            6'b001001 : NEW_RAND <= {RANDOMNESS[775:768],RANDOMNESS[783:776],RANDOMNESS[791:784],RANDOMNESS[799:792]};
            6'b001010 : NEW_RAND <= {RANDOMNESS[743:736],RANDOMNESS[751:744],RANDOMNESS[759:752],RANDOMNESS[767:760]};
            6'b001011 : NEW_RAND <= {RANDOMNESS[711:704],RANDOMNESS[719:712],RANDOMNESS[727:720],RANDOMNESS[735:728]};
            6'b001100 : NEW_RAND <= {RANDOMNESS[679:672],RANDOMNESS[687:680],RANDOMNESS[695:688],RANDOMNESS[703:696]};
            6'b001101 : NEW_RAND <= {RANDOMNESS[647:640],RANDOMNESS[655:648],RANDOMNESS[663:656],RANDOMNESS[671:664]};
            6'b001110 : NEW_RAND <= {RANDOMNESS[615:608],RANDOMNESS[623:616],RANDOMNESS[631:624],RANDOMNESS[639:632]};
            6'b001111 : NEW_RAND <= {RANDOMNESS[583:576],RANDOMNESS[591:584],RANDOMNESS[599:592],RANDOMNESS[607:600]};
            6'b010000 : NEW_RAND <= {RANDOMNESS[551:544],RANDOMNESS[559:552],RANDOMNESS[567:560],RANDOMNESS[575:568]};
            6'b010001 : NEW_RAND <= {RANDOMNESS[519:512],RANDOMNESS[527:520],RANDOMNESS[535:528],RANDOMNESS[543:536]};
            6'b010010 : NEW_RAND <= {RANDOMNESS[487:480],RANDOMNESS[495:488],RANDOMNESS[503:496],RANDOMNESS[511:504]};
            6'b010011 : NEW_RAND <= {RANDOMNESS[455:448],RANDOMNESS[463:456],RANDOMNESS[471:464],RANDOMNESS[479:472]};
            6'b010100 : NEW_RAND <= {RANDOMNESS[423:416],RANDOMNESS[431:424],RANDOMNESS[439:432],RANDOMNESS[447:440]};
            6'b010101 : NEW_RAND <= {RANDOMNESS[391:384],RANDOMNESS[399:392],RANDOMNESS[407:400],RANDOMNESS[415:408]};
            6'b010110 : NEW_RAND <= {RANDOMNESS[359:352],RANDOMNESS[367:360],RANDOMNESS[375:368],RANDOMNESS[383:376]};
            6'b010111 : NEW_RAND <= {RANDOMNESS[327:320],RANDOMNESS[335:328],RANDOMNESS[343:336],RANDOMNESS[351:344]};
            6'b011000 : NEW_RAND <= {RANDOMNESS[295:288],RANDOMNESS[303:296],RANDOMNESS[311:304],RANDOMNESS[319:312]};
            6'b011001 : NEW_RAND <= {RANDOMNESS[263:256],RANDOMNESS[271:264],RANDOMNESS[279:272],RANDOMNESS[287:280]};
            6'b011010 : NEW_RAND <= {RANDOMNESS[231:224],RANDOMNESS[239:232],RANDOMNESS[247:240],RANDOMNESS[255:248]};
            6'b011011 : NEW_RAND <= {RANDOMNESS[199:192],RANDOMNESS[207:200],RANDOMNESS[215:208],RANDOMNESS[223:216]};
            6'b011100 : NEW_RAND <= {RANDOMNESS[167:160],RANDOMNESS[175:168],RANDOMNESS[183:176],RANDOMNESS[191:184]};
            6'b011101 : NEW_RAND <= {RANDOMNESS[135:128],RANDOMNESS[143:136],RANDOMNESS[151:144],RANDOMNESS[159:152]};
            6'b011110 : NEW_RAND <= {RANDOMNESS[103:96],RANDOMNESS[111:104],RANDOMNESS[119:112],RANDOMNESS[127:120]};
            6'b011111 : NEW_RAND <= {RANDOMNESS[71:64],RANDOMNESS[79:72],RANDOMNESS[87:80],RANDOMNESS[95:88]};
            6'b100000 : NEW_RAND <= {RANDOMNESS[39:32],RANDOMNESS[47:40],RANDOMNESS[55:48],RANDOMNESS[63:56]};
            6'b100001 : NEW_RAND <= {RANDOMNESS[7:0],RANDOMNESS[15:8],RANDOMNESS[23:16],RANDOMNESS[31:24]};
            default : NEW_RAND <= {32{1'b0}};
        endcase
    end

    // mask randomness and subtract R_BITS (is used for sampling e1)
    assign NEW_POSITION         = NEW_RAND[int'($clog2(N_BITS))-1:0];
    assign NEW_POSITION_DIFF    = (((NEW_POSITION)) - R_BITS);
    //----------------------------------------------------------------------------
    
    // SAMPLER -------------------------------------------------------------------    
    // IO
    assign e_compact_rden = RDEN_1 | RDEN_2;
    assign e_compact_wren = WREN_1 | WREN_2;
    assign e_compact_addr = {{(LOGSWORDS-int'($clog2(THRESHOLD+1))){1'b0}}, CNT_OUT};
    assign e_compact_dout = new_position_compact;
    
    assign new_position_e0 = {{(32-LOGRBITS-1){1'b0}}, 1'b1, NEW_POSITION[LOGRBITS-1:0]};
    assign new_position_e1 = {{(32-LOGRBITS-1){1'b0}}, 1'b0, NEW_POSITION_DIFF[LOGRBITS-1:0]};
    assign new_position_compact = (WREN_1 == 1'b1) ? new_position_e0 : new_position_e1;
    
    
    assign DOUT     = DIN[BIT_POSITION[4:0]] == 1'b0 ? DIN ^ NEW_BIT : DIN; //DIN XOR NEW_BIT WHEN DIN(to_integer(unsigned(BIT_POSITION(4 DOWNTO 0)))) = '0' ELSE DIN;
    
    // select correct input 
    assign DIN      = NEW_POSITION_DIFF[int'($clog2(N_BITS))-1] == 1'b1 ? DIN_1 : DIN_2;
    
    // ADDRESS
    assign ADDR     = NEW_POSITION_DIFF[int'($clog2(N_BITS))-1] == 1'b1 ? NEW_POSITION[int'($clog2(N_BITS))-2:5] : NEW_POSITION_DIFF[int'($clog2(N_BITS))-2:5];
  
    // READ/WRITE CONTROL
    assign RDEN_1   = NEW_POSITION_DIFF[int'($clog2(N_BITS))-1] & RDEN; // the msb of the difference selects e0/e1
    assign WREN_1   = NEW_POSITION_DIFF[int'($clog2(N_BITS))-1] & WREN;
    assign RDEN_2   = (( ~NEW_POSITION_DIFF[int'($clog2(N_BITS))-1])) & RDEN;
    assign WREN_2   = (( ~NEW_POSITION_DIFF[int'($clog2(N_BITS))-1])) & WREN;
  
    // check if randomness >= N_BITS
    assign VALID_RAND = NEW_POSITION >= N_BITS ? 1'b0 : 1'b1;  // '0' WHEN NEW_POSITION >= STD_LOGIC_VECTOR(TO_UNSIGNED(N_BITS, LOG2(N_BITS))) ELSE '1';
    assign BIT_POSITION = NEW_POSITION_DIFF[int'($clog2(N_BITS))-1] == 1'b 1 ? NEW_POSITION[4:0] : NEW_POSITION_DIFF[4:0];
  
    // ONE-HOT ENCODING
    always @(BIT_POSITION) begin
        case(BIT_POSITION)
            5'b 00000 : NEW_BIT <= 32'h 00000001;
            5'b 00001 : NEW_BIT <= 32'h 00000002;
            5'b 00010 : NEW_BIT <= 32'h 00000004;
            5'b 00011 : NEW_BIT <= 32'h 00000008;
            5'b 00100 : NEW_BIT <= 32'h 00000010;
            5'b 00101 : NEW_BIT <= 32'h 00000020;
            5'b 00110 : NEW_BIT <= 32'h 00000040;
            5'b 00111 : NEW_BIT <= 32'h 00000080;
            5'b 01000 : NEW_BIT <= 32'h 00000100;
            5'b 01001 : NEW_BIT <= 32'h 00000200;
            5'b 01010 : NEW_BIT <= 32'h 00000400;
            5'b 01011 : NEW_BIT <= 32'h 00000800;
            5'b 01100 : NEW_BIT <= 32'h 00001000;
            5'b 01101 : NEW_BIT <= 32'h 00002000;
            5'b 01110 : NEW_BIT <= 32'h 00004000;
            5'b 01111 : NEW_BIT <= 32'h 00008000;
            5'b 10000 : NEW_BIT <= 32'h 00010000;
            5'b 10001 : NEW_BIT <= 32'h 00020000;
            5'b 10010 : NEW_BIT <= 32'h 00040000;
            5'b 10011 : NEW_BIT <= 32'h 00080000;
            5'b 10100 : NEW_BIT <= 32'h 00100000;
            5'b 10101 : NEW_BIT <= 32'h 00200000;
            5'b 10110 : NEW_BIT <= 32'h 00400000;
            5'b 10111 : NEW_BIT <= 32'h 00800000;
            5'b 11000 : NEW_BIT <= 32'h 01000000;
            5'b 11001 : NEW_BIT <= 32'h 02000000;
            5'b 11010 : NEW_BIT <= 32'h 04000000;
            5'b 11011 : NEW_BIT <= 32'h 08000000;
            5'b 11100 : NEW_BIT <= 32'h 10000000;
            5'b 11101 : NEW_BIT <= 32'h 20000000;
            5'b 11110 : NEW_BIT <= 32'h 40000000;
            5'b 11111 : NEW_BIT <= 32'h 80000000;
            default :   NEW_BIT <= 32'h 00000000;
        endcase
    end
    //----------------------------------------------------------------------------
    
    // COUNTER -------------------------------------------------------------------
    assign CNT_ENABLE = DIN[BIT_POSITION[4:0]] == 1'b0 && CNT_VALID == 1'b1 && VALID_RAND == 1'b1 ? 1'b1 : 1'b0;
    BIKE_counter_inc_stop #(.SIZE(int'($clog2(THRESHOLD+1))), .MAX_VALUE(THRESHOLD))
    counter (.clk(CLK), .enable(CNT_ENABLE), .resetn(CNT_RESETN), .cnt_out(CNT_OUT));
    
    BIKE_counter_inc #(.SIZE(int'($clog2(42))), .MAX_VALUE(34))
    round_counter (.clk(CLK), .enable(CNT_RND_EN), .resetn(CNT_RND_RSTN), .cnt_out(CNT_RND_OUT));
    //----------------------------------------------------------------------------
  
    // FINITE STATE MACHINE PROCESS ----------------------------------------------
    always @(posedge CLK) begin
        case(STATE)
            //--------------------------------------------
            S_RESET : begin
                // GLOBAL ----------
                DONE            <= 1'b0;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b0;
                CNT_VALID       <= 1'b0;
                CNT_RND_RSTN    <= 1'b0;
                CNT_RND_EN      <= 1'b0;
                
                // BRAM ------------
                RDEN            <= 1'b0;
                WREN            <= 1'b0;
                
                // PRNG ------------
                KECCAK_INIT     <= 1'b0;
                KECCAK_ENABLE   <= 1'b0;
                
                // TRANSITION ------
                if((ENABLE == 1'b1)) begin
                    STATE       <= S_KECCAK_INIT;
                end
                else begin
                    STATE       <= S_RESET;
                end
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_KECCAK_INIT : begin
                // GLOBAL ----------
                DONE            <= 1'b0;
                // COUNTER ---------
                CNT_RESETN      <= 1'b1;
                CNT_VALID       <= 1'b0;
                CNT_RND_RSTN    <= 1'b0;
                CNT_RND_EN      <= 1'b0;
                
                // BRAM ------------
                RDEN            <= 1'b0;
                WREN            <= 1'b0;
                
                // PRNG ------------
                KECCAK_INIT     <= 1'b1;
                KECCAK_ENABLE   <= 1'b1;
                
                // TRANSITION ------
                STATE           <= S_KECCAK;
            end
            //--------------------------------------------
    
            //--------------------------------------------
            S_KECCAK_INIT1 : begin
                // GLOBAL ----------
                DONE            <= 1'b0;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b1;
                CNT_VALID       <= 1'b0;
                CNT_RND_RSTN    <= 1'b0;
                CNT_RND_EN      <= 1'b0;
                
                // BRAM ------------
                RDEN            <= 1'b 0;
                WREN            <= 1'b 0;
                // PRNG ------------
                KECCAK_INIT     <= 1'b0;
                KECCAK_ENABLE   <= 1'b1;
                
                // TRANSITION ------
                STATE           <= S_KECCAK;
            end
            //--------------------------------------------
            
            //--------------------------------------------
            S_KECCAK : begin
                // GLOBAL ----------
                DONE            <= 1'b0;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b1;
                CNT_VALID       <= 1'b0;
                CNT_RND_RSTN    <= 1'b0;
                CNT_RND_EN      <= 1'b0;
                
                // PRNG ------------
                KECCAK_INIT     <= 1'b0;
                KECCAK_ENABLE   <= 1'b0;
                
                // TRANSITION ------
                if((KECCAK_DONE == 1'b1)) begin
                    RDEN        <= 1'b1;
                    WREN        <= 1'b0;
                    STATE       <= S_SAMPLE_READ;
                end
                else begin
                    RDEN        <= 1'b0;
                    WREN        <= 1'b0;
                    STATE       <= S_KECCAK;
                end
            end
            //--------------------------------------------
    
            //--------------------------------------------
            S_SAMPLE_READ : begin
                if (CNT_OUT == THRESHOLD) begin
                    // TRANSITION --
                    STATE       <= S_DONE;
                    
                    // GLOBAL ------
                    DONE        <= 1'b1;
                    
                    // COUNTER -----
                    CNT_VALID   <= 1'b0;
                    CNT_RESETN  <= 1'b0;
                    CNT_RND_RSTN <= 1'b1;
                    CNT_RND_EN  <= 1'b0;
                    
                    // BRAM --------
                    RDEN        <= 1'b0;
                    WREN        <= 1'b0;
                    
                    // PRNG ------------
                    KECCAK_INIT     <= 1'b0;
                    KECCAK_ENABLE   <= 1'b0;
                end
                else begin
                    // TRANSITION --
                    STATE       <= S_SAMPLE_WRITE;
                    
                    // GLOBAL ------
                    DONE        <= 1'b0;
                    
                    // COUNTER -----
                    CNT_VALID   <= 1'b1;
                    CNT_RESETN  <= 1'b1;
                    CNT_RND_RSTN <= 1'b1;
                    CNT_RND_EN  <= 1'b 1;
                    
                    // BRAM --------
                    RDEN        <= 1'b1;
                    WREN        <= 1'b1 & VALID_RAND;
                    
                    // PRNG --------
                    KECCAK_INIT     <= 1'b0;
                    KECCAK_ENABLE   <= 1'b0;
                end
            end
            //--------------------------------------------
    
            //--------------------------------------------
            S_SAMPLE_WRITE : begin
                // TRANSITION --
                if (CNT_RND_OUT == 33) begin
                    STATE       <= S_KECCAK_INIT1;
                end
                else begin
                    STATE       <= S_SAMPLE_READ;
                end
                
                // GLOBAL ------
                DONE            <= 1'b0;
                
                // COUNTER -----
                CNT_VALID       <= 1'b0;
                CNT_RESETN      <= 1'b1;
                CNT_RND_RSTN    <= 1'b1;
                CNT_RND_EN      <= 1'b0;
                
                // BRAM --------
                RDEN            <= 1'b1;
                WREN            <= 1'b0;
                
                // PRNG --------  
                KECCAK_INIT     <= 1'b0;
                KECCAK_ENABLE   <= 1'b0;
            end
            //--------------------------------------------
    
            //--------------------------------------------
            S_DONE : begin
                // GLOBAL ----------
                DONE            <= 1'b1;
                
                // COUNTER ---------
                CNT_RESETN      <= 1'b0;
                CNT_VALID       <= 1'b0;
                CNT_RND_RSTN    <= 1'b0;
                CNT_RND_EN      <= 1'b0;
                
                // BRAM --------
                RDEN            <= 1'b0;
                WREN            <= 1'b0;
                
                // PRNG --------
                KECCAK_INIT     <= 1'b0;
                KECCAK_ENABLE   <= 1'b0;
                
                // TRANSITION ------
                if(RESETN == 1'b0) begin
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
