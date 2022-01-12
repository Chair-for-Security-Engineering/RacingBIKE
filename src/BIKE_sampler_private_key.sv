//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         15.03.2021 
// Module Name:         BIKE_sampler_private_key
// Description:         Private key sampler.
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

module BIKE_sampler_private_key
    #(  
        parameter THRESHOLD = 10
    )(
        input  wire clk,
        input  wire resetn,
        input  wire enable,
        output reg  done,
        // keccak
        input  wire [255:0] keccak_seed,
        output reg  keccak_enable,
        output reg  keccak_init,
        input  wire keccak_done,
        output wire [STATE_WIDTH-1:0] keccak_m,
        input  wire [STATE_WIDTH-1:0] keccak_out,
        // memory
        output wire h0_rden,
        output wire h1_rden,
        output wire h0_wren,
        output wire h1_wren,
        output wire [LOGDWORDS-1:0] h_addr,
        output wire [31:0] h_dout,
        input  wire [31:0] h0_din,
        input  wire [31:0] h1_din,
        // compact representation
        output wire h0_compact_rden,
        output wire h1_compact_rden,
        output wire h0_compact_wren,
        output wire h1_compact_wren,
        output wire [LOGDWORDS-1:0] h_compact_addr,
        output wire [31:0] h_compact_dout
);



// Parameter
parameter integer DIGIST_SIZE = 1088;


// Wires and registers ///////////////////////////////////////////////////////////
// COUNTER
reg  cnt_resetn; 
wire cnt_enable; 
reg  cnt_valid;
wire [int'($clog2(THRESHOLD+1))-1:0] cnt_out;

reg  cnt_rnd_resetn; 
reg  cnt_rnd_enable;
wire [5:0] cnt_rnd_out;  

// SAMPLER
reg  [31:0] new_rand;
wire [int'($clog2(R_BITS))-1:0] new_position; 
wire [4:0] bit_position;
reg  [31:0] new_bit;
wire valid_rand;
wire [31:0] din;  

// PRNG
wire [1343:0] randomness;  

reg rden0;
reg rden1;
reg wren0;
reg wren1;

   



// Description ///////////////////////////////////////////////////////////////////



    // PRNG ----------------------------------------------------------------------
    // reorder seed in order to match software implementation
    generate 
        for (genvar I=0; I <= 31; I = I + 1) begin
            assign keccak_m[(I*8+7):(I*8)] = keccak_seed[(255-I*8):(248-I*8)];
        end
    endgenerate
    
    assign keccak_m[260:256] = 5'b11111;
    assign keccak_m[DIGIST_SIZE-2:261] = 'b0;
    assign keccak_m[DIGIST_SIZE-1] = 1'b1;
    assign keccak_m[1599:DIGIST_SIZE] = {256{1'b0}};
    assign randomness = keccak_out[STATE_WIDTH - 1:STATE_WIDTH - DIGIST_SIZE];
    
    // Random output is divided into fout 32-bit blocks of randomness    
    always @(*) begin
        case(cnt_rnd_out)
            6'b000000 : new_rand = {randomness[1063:1056],randomness[1071:1064],randomness[1079:1072],randomness[1087:1080]};
            6'b000001 : new_rand = {randomness[1031:1024],randomness[1039:1032],randomness[1047:1040],randomness[1055:1048]};
            6'b000010 : new_rand = {randomness[999:992],randomness[1007:1000],randomness[1015:1008],randomness[1023:1016]};  
            6'b000011 : new_rand = {randomness[967:960],randomness[975:968],randomness[983:976],randomness[991:984]};        
            6'b000100 : new_rand = {randomness[935:928],randomness[943:936],randomness[951:944],randomness[959:952]};        
            6'b000101 : new_rand = {randomness[903:896],randomness[911:904],randomness[919:912],randomness[927:920]};        
            6'b000110 : new_rand = {randomness[871:864],randomness[879:872],randomness[887:880],randomness[895:888]};        
            6'b000111 : new_rand = {randomness[839:832],randomness[847:840],randomness[855:848],randomness[863:856]};        
            6'b001000 : new_rand = {randomness[807:800],randomness[815:808],randomness[823:816],randomness[831:824]};        
            6'b001001 : new_rand = {randomness[775:768],randomness[783:776],randomness[791:784],randomness[799:792]};
            6'b001010 : new_rand = {randomness[743:736],randomness[751:744],randomness[759:752],randomness[767:760]};
            6'b001011 : new_rand = {randomness[711:704],randomness[719:712],randomness[727:720],randomness[735:728]};
            6'b001100 : new_rand = {randomness[679:672],randomness[687:680],randomness[695:688],randomness[703:696]};
            6'b001101 : new_rand = {randomness[647:640],randomness[655:648],randomness[663:656],randomness[671:664]};
            6'b001110 : new_rand = {randomness[615:608],randomness[623:616],randomness[631:624],randomness[639:632]};
            6'b001111 : new_rand = {randomness[583:576],randomness[591:584],randomness[599:592],randomness[607:600]};
            6'b010000 : new_rand = {randomness[551:544],randomness[559:552],randomness[567:560],randomness[575:568]};
            6'b010001 : new_rand = {randomness[519:512],randomness[527:520],randomness[535:528],randomness[543:536]};
            6'b010010 : new_rand = {randomness[487:480],randomness[495:488],randomness[503:496],randomness[511:504]};
            6'b010011 : new_rand = {randomness[455:448],randomness[463:456],randomness[471:464],randomness[479:472]};
            6'b010100 : new_rand = {randomness[423:416],randomness[431:424],randomness[439:432],randomness[447:440]};
            6'b010101 : new_rand = {randomness[391:384],randomness[399:392],randomness[407:400],randomness[415:408]};
            6'b010110 : new_rand = {randomness[359:352],randomness[367:360],randomness[375:368],randomness[383:376]};
            6'b010111 : new_rand = {randomness[327:320],randomness[335:328],randomness[343:336],randomness[351:344]};
            6'b011000 : new_rand = {randomness[295:288],randomness[303:296],randomness[311:304],randomness[319:312]};
            6'b011001 : new_rand = {randomness[263:256],randomness[271:264],randomness[279:272],randomness[287:280]};
            6'b011010 : new_rand = {randomness[231:224],randomness[239:232],randomness[247:240],randomness[255:248]};
            6'b011011 : new_rand = {randomness[199:192],randomness[207:200],randomness[215:208],randomness[223:216]};
            6'b011100 : new_rand = {randomness[167:160],randomness[175:168],randomness[183:176],randomness[191:184]};
            6'b011101 : new_rand = {randomness[135:128],randomness[143:136],randomness[151:144],randomness[159:152]};
            6'b011110 : new_rand = {randomness[103:96],randomness[111:104],randomness[119:112],randomness[127:120]};
            6'b011111 : new_rand = {randomness[71:64],randomness[79:72],randomness[87:80],randomness[95:88]};
            6'b100000 : new_rand = {randomness[39:32],randomness[47:40],randomness[55:48],randomness[63:56]};
            6'b100001 : new_rand = {randomness[7:0],randomness[15:8],randomness[23:16],randomness[31:24]};
            default : new_rand = {32{1'b0}};
        endcase
    end

    // mask randomness and subtract R_BITS (is used for sampling e1)
    assign new_position = new_rand[int'($clog2(R_BITS))-1:0];



    // SAMPLER -------------------------------------------------------------------    
    // IO
    assign h0_compact_rden = rden0;
    assign h1_compact_rden = rden1;
    assign h0_compact_wren = (din[bit_position[4:0]] == 1'b0) ? wren0 & valid_rand : 1'b0;
    assign h1_compact_wren = (din[bit_position[4:0]] == 1'b0) ? wren1 & valid_rand : 1'b0;
    assign h_compact_addr = {{(LOGDWORDS-int'($clog2(THRESHOLD+1))){1'b0}}, cnt_out};
    assign h_compact_dout = {{(32-int'($clog2(R_BITS))){1'b0}}, new_position};
    
    
    assign din       = (rden0 == 1'b1) ? h0_din : h1_din;
    
    assign h_dout    = (din[bit_position[4:0]] == 1'b0) ? din ^ new_bit : din; 
    
    // ADDRESS
    assign h_addr    = new_position[int'($clog2(N_BITS))-2:5];
  
    // READ/WRITE CONTROL
    assign h0_rden   = rden0; 
    assign h0_wren   = wren0 & valid_rand;
    assign h1_rden   = rden1;
    assign h1_wren   = wren1 & valid_rand;
  
    // check if randomness >= R_BITS
    assign valid_rand = (new_position >= R_BITS) ? 1'b0 : 1'b1; 
    assign bit_position = new_position[4:0];
  
    // ONE-HOT ENCODING
    always @(bit_position) begin
        case(bit_position)
            5'b 00000 : new_bit = 32'h00000001;
            5'b 00001 : new_bit = 32'h00000002;
            5'b 00010 : new_bit = 32'h00000004;
            5'b 00011 : new_bit = 32'h00000008;
            5'b 00100 : new_bit = 32'h00000010;
            5'b 00101 : new_bit = 32'h00000020;
            5'b 00110 : new_bit = 32'h00000040;
            5'b 00111 : new_bit = 32'h00000080;
            5'b 01000 : new_bit = 32'h00000100;
            5'b 01001 : new_bit = 32'h00000200;
            5'b 01010 : new_bit = 32'h00000400;
            5'b 01011 : new_bit = 32'h00000800;
            5'b 01100 : new_bit = 32'h00001000;
            5'b 01101 : new_bit = 32'h00002000;
            5'b 01110 : new_bit = 32'h00004000;
            5'b 01111 : new_bit = 32'h00008000;
            5'b 10000 : new_bit = 32'h00010000;
            5'b 10001 : new_bit = 32'h00020000;
            5'b 10010 : new_bit = 32'h00040000;
            5'b 10011 : new_bit = 32'h00080000;
            5'b 10100 : new_bit = 32'h00100000;
            5'b 10101 : new_bit = 32'h00200000;
            5'b 10110 : new_bit = 32'h00400000;
            5'b 10111 : new_bit = 32'h00800000;
            5'b 11000 : new_bit = 32'h01000000;
            5'b 11001 : new_bit = 32'h02000000;
            5'b 11010 : new_bit = 32'h04000000;
            5'b 11011 : new_bit = 32'h08000000;
            5'b 11100 : new_bit = 32'h10000000;
            5'b 11101 : new_bit = 32'h20000000;
            5'b 11110 : new_bit = 32'h40000000;
            5'b 11111 : new_bit = 32'h80000000;
            default :   new_bit = 32'h00000000;
        endcase
    end
    //----------------------------------------------------------------------------


    // COUNTER -------------------------------------------------------------------
    assign cnt_enable = (din[bit_position[4:0]] == 1'b0 && cnt_valid == 1'b1 && valid_rand == 1'b1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(THRESHOLD+1))), .MAX_VALUE(THRESHOLD))
    counter (.clk(clk), .enable(cnt_enable), .resetn(cnt_resetn), .cnt_out(cnt_out));
    
    BIKE_counter_inc #(.SIZE(int'($clog2(42))), .MAX_VALUE(42))
    round_counter (.clk(clk), .enable(cnt_rnd_enable), .resetn(cnt_rnd_resetn), .cnt_out(cnt_rnd_out));
    //----------------------------------------------------------------------------


    // FSM //////////////////////////////////////////////////////////////////////
    reg [3:0] state_reg, state_next;
    localparam [3:0]
        s_idle              = 0,
        s_keccak_init0      = 1,
        s_keccak_init1      = 2,
        s_keccak            = 3,
        s_keccak_init1_2    = 4,
        s_keccak_2          = 5,
        s_sample_h0_read    = 6,
        s_sample_h0_write   = 7,
        s_sample_reset_cnt  = 8,
        s_sample_h1_read    = 9,
        s_sample_h1_write   = 10,
        s_done              = 11;

            
    // state register
    always @ (posedge clk) begin
        if(~resetn) begin
            state_reg <= s_idle;
        end
        else begin
            state_reg <= state_next;
        end
    end 

    // Next state logic
    always @(*) begin
        state_next = state_reg;
        
        case(state_reg)
        
            // -----------------------------------
            s_idle : begin
                if(enable) begin
                    state_next      = s_keccak_init0;
                end                
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_init0 : begin
                state_next          = s_keccak;             
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_init1 : begin
                state_next          = s_keccak;             
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak : begin
                if(keccak_done) begin
                    state_next      = s_sample_h0_read; 
                end                            
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_init1_2 : begin
                state_next          = s_keccak_2;             
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_2 : begin
                if(keccak_done) begin
                    state_next      = s_sample_h1_read; 
                end                            
            end
            // -----------------------------------
            
            // -----------------------------------
            s_sample_h0_read : begin
                if(cnt_out == (THRESHOLD)) begin
                    state_next      = s_sample_reset_cnt; 
                end        
                else begin
                    state_next      = s_sample_h0_write;
                end    
            end                                          
            // -----------------------------------
            
            // -----------------------------------
            s_sample_h0_write : begin
                if(cnt_rnd_out == 33) begin
                    state_next          = s_keccak_init1;
                end
                else begin 
                    state_next          = s_sample_h0_read;   
                end                                
            end
            // -----------------------------------
            
            // -----------------------------------
            s_sample_reset_cnt : begin
                state_next              = s_sample_h1_read;                                   
            end
            // -----------------------------------

            // -----------------------------------
            s_sample_h1_read : begin
                if(cnt_out == (THRESHOLD)) begin
                    state_next      = s_done; 
                end        
                else begin
                    state_next      = s_sample_h1_write;
                end    
            end                                          
            // -----------------------------------   
            
            // -----------------------------------
            s_sample_h1_write : begin
                if(cnt_rnd_out == 33) begin
                    state_next          = s_keccak_init1_2;
                end
                else begin 
                    state_next          = s_sample_h1_read;
               end                                                   
            end
            // -----------------------------------     

            // -----------------------------------
            s_done : begin
                state_next              = s_done;                                   
            end
            // -----------------------------------               
                                                                            
        endcase
    
    end


    // output logic
    always @(state_reg) begin
        done                        = 1'b0;
 
        // COUNTER ---------
        cnt_resetn          = 1'b0;
        cnt_valid           = 1'b0;
        cnt_rnd_resetn      = 1'b0;
        cnt_rnd_enable      = 1'b0;
        
        // BRAM ------------
        rden0               = 1'b0;
        rden1               = 1'b0;
        wren0               = 1'b0;
        wren1               = 1'b0;
        
        // PRNG ------------
        keccak_init         = 1'b0;
        keccak_enable       = 1'b0;
        
        case (state_reg)
        
            // -----------------------------------
            s_keccak_init0 : begin
                // Counter
                cnt_resetn          = 1'b1;
                
                // keccak
                keccak_init         = 1'b1;
                keccak_enable       = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_init1 : begin
                // Counter
                cnt_resetn          = 1'b1;
                
                // keccak
                keccak_init         = 1'b0;
                keccak_enable       = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak : begin
                // Counter
                cnt_resetn          = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_init1_2 : begin
                // Counter
                cnt_resetn          = 1'b1;
                
                // keccak
                keccak_init         = 1'b0;
                keccak_enable       = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_keccak_2 : begin
                // Counter
                cnt_resetn          = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_sample_h0_read : begin
                // Counter
                cnt_resetn          = 1'b1;
                cnt_rnd_resetn      = 1'b1;
                
                rden0               = 1'b1;     
            end
            // -----------------------------------

            // -----------------------------------
            s_sample_h0_write : begin
                // Counter
                cnt_valid           = 1'b1;
                cnt_resetn          = 1'b1;
                cnt_rnd_resetn      = 1'b1;
                cnt_rnd_enable      = 1'b1;
                                
                rden0               = 1'b1;
                wren0               = 1'b1;            
            end
            // -----------------------------------                                                

            // -----------------------------------
            s_sample_reset_cnt : begin
                // Counter
                cnt_rnd_resetn      = 1'b1;            
            end
            // -----------------------------------
            
            // -----------------------------------
            s_sample_h1_read : begin
                // Counter
                cnt_resetn          = 1'b1;
                cnt_rnd_resetn      = 1'b1;
                
                rden1               = 1'b1;     
            end
            // -----------------------------------

            // -----------------------------------
            s_sample_h1_write : begin
                // Counter
                cnt_valid           = 1'b1;
                cnt_resetn          = 1'b1;
                cnt_rnd_resetn      = 1'b1;
                cnt_rnd_enable      = 1'b1;
                                
                rden1               = 1'b1;
                wren1               = 1'b1;        
            end
            // ----------------------------------- 

            // -----------------------------------
            s_done : begin
                done                = 1'b1;     
            end
            // -----------------------------------
                                
        endcase
    end



endmodule

