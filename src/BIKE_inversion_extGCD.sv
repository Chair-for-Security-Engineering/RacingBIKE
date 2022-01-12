`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Ruhr-Universit�t Bochum
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         09.04.2021 
// Module Name:         BIKE_key_generation
// Description:         Key generation of BIKE - testing a new inversion strategy.
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



module BIKE_inversion_extGCD #(
        parameter STEPS = 32
    )(
        input  wire clk,
        input  wire resetn,
        input  wire enable,
        output reg  done,
        // Memory 0
        output reg  mem_rden [7:0],
        output reg  mem_wren [7:0],
        output reg  [LOGSWORDS-1:0] mem_addr [7:0],
        output reg  [B_WIDTH-1:0] mem_dout [7:0],
        input  wire [B_WIDTH-1:0] mem_din [7:0]
    );
    
    
    parameter ITERATIONS = div_and_floor(2*R_BITS-1, STEPS);                                // number of shift and add iterations
    parameter UNROLLING_DELTA = 2;                                                          // number of control bits computed per clock cycles
    parameter ITERATIONS_DELTA = div_and_ceil(STEPS, UNROLLING_DELTA);                      // number of iterations to compute all control bits
    
    parameter SERIAL_STAGES_FG_RV = my_min(8, STEPS);                                       // number of determined bits for polynomials f,g and r,v per clock cycle
    parameter PIPELINE_STAGES_FG_RV = div_and_ceil(STEPS, SERIAL_STAGES_FG_RV);             // pipeline stages for computing polynomials f,g and r,v
    
    parameter REMAINDER = 2*R_BITS-1 - div_and_floor(2*R_BITS-1, STEPS)*STEPS;              // number of bits for the last shift and add iterations
    parameter PIPELINE_STAGES_REMAINDER = div_and_ceil(REMAINDER, SERIAL_STAGES_FG_RV);     // pipeline stages required in the last iteration
    
    
    parameter CNT0_SIZE = my_max(SWORDS, STEPS);
    // Registers and wires //////////////////////////////////////////////////////
    reg  [1:0] memory_selection [7:0];
    
    // Counter
    reg  cnt_dec0_enable;
    reg  cnt_dec0_resetn;
    wire [LOGSWORDS-1:0] cnt_dec0_out;

    reg  cnt_dec1_enable;
    reg  cnt_dec1_resetn;
    wire [LOGSWORDS-1:0] cnt_dec1_out;
    
    reg  cnt_inc1_enable;
    reg  cnt_inc1_resetn;
    wire [$clog2(SWORDS+PIPELINE_STAGES_FG_RV)-1:0] cnt_inc1_out;
    
    reg  cnt_inc0_enable;
    reg  cnt_inc0_resetn;
    wire [$clog2(CNT0_SIZE)-1:0] cnt_inc0_out;
    wire cnt_inc0_done;

    reg  cnt_inc2_enable;
    reg  cnt_inc2_resetn;
    wire [$clog2(2*R_BITS)-1:0] cnt_inc2_out;
    wire cnt_inc2_done;
        
    // Overhang register
    reg  overhang_reg_enable;
    reg  overhang_reg_resetn;
    reg  [OVERHANG-1:0] overhang_reg;
    wire [OVERHANG-1:0] overhang_reg_in;
    wire [OVERHANG-1:0] overhang_reg_in2;
    
    // Bitreversing
    wire [B_WIDTH-1:0] word_reversed;
    
    // Iteration
    wire iteration_rden [7:0];
    wire iteration_wren [7:0];
    wire [LOGSWORDS-1:0] iteration_addr [7:0];
    wire [B_WIDTH-1:0] iteration_dout [7:0];
    
    reg  [2*STEPS-1:0] control_bits;
    wire [2*STEPS-1:0] control_bits_in;
    
    wire [2*UNROLLING_DELTA-1:0] control_bits_batch_in;
    wire f0g0 [UNROLLING_DELTA-1:0];
    wire [STEPS-2:0] f_and_f0g0 [UNROLLING_DELTA-1:0];
    wire swap_bit [UNROLLING_DELTA-1:0];
    wire [STEPS-1:0] f0_iter [UNROLLING_DELTA:0];
    wire [STEPS-1:0] g0_iter [UNROLLING_DELTA:0];
    
    reg  [STEPS-1:0] f0_iter_reg;
    reg  [STEPS-1:0] g0_iter_reg;
            
    reg  swap_rden;
    reg  swap_en;
    
    reg  remainder_enable;

    wire [B_WIDTH-1:0] delta_in [UNROLLING_DELTA:0];
    wire [B_WIDTH-1:0] delta_neg [UNROLLING_DELTA-1:0];
    reg  [B_WIDTH-1:0] delta;
    wire [B_WIDTH-1:0] delta_reg_in;

    
    
    wire [B_WIDTH+STEPS-1:0] f_steps [STEPS-1:0];
    wire [B_WIDTH+STEPS-1:0] g_steps [STEPS-1:0];
    reg  [B_WIDTH+STEPS-1:0] reg_f_in [PIPELINE_STAGES_FG_RV-1:0];
    reg  [B_WIDTH+STEPS-1:0] reg_g_in [PIPELINE_STAGES_FG_RV-1:0];
    
    wire [B_WIDTH+STEPS-1:0] r_steps [STEPS-1:0];
    wire [B_WIDTH+STEPS-1:0] v_steps [STEPS-1:0];
    reg  [B_WIDTH+STEPS-1:0] reg_r_in [PIPELINE_STAGES_FG_RV-1:0];
    reg  [B_WIDTH+STEPS-1:0] reg_v_in [PIPELINE_STAGES_FG_RV-1:0];
    
    wire [B_WIDTH-1:0] g_new;
    wire [B_WIDTH-1:0] f_new;
    wire [B_WIDTH-1:0] r_new;
    wire [B_WIDTH-1:0] v_new;
        
    reg  it_rden;
    reg  it_wren;
    
    reg  tracking_en;
    wire track_poly_in;
    reg  track_poly;
    reg  [B_WIDTH-1:0] poly_g;
    reg  [B_WIDTH-1:0] poly_f;
    reg  [B_WIDTH-1:0] poly_g_reg;
    reg  [B_WIDTH-1:0] poly_f_reg;
    
    reg  track_r_v_in;
    reg  track_r_v;
    reg  [B_WIDTH-1:0] poly_r;
    reg  [B_WIDTH-1:0] poly_v;
    reg  [B_WIDTH-1:0] poly_r_reg;
    reg  [B_WIDTH-1:0] poly_v_reg;
        
    wire [LOGSWORDS-1:0] addr_g_f;
    wire [LOGSWORDS-1:0] addr_r_v;
    
    reg  [STEPS-1:0] f0;
    reg  [STEPS-1:0] g0;
    
    // final shift and reverse
    reg  final_shift;
    reg  reg_shift_right;
    wire reg_shift_right_in;
    wire final_shift_wren [1:0];
    wire [LOGSWORDS-1:0] final_shift_addr [1:0];
    wire [B_WIDTH-1:0] final_shift_din [1:0];
    wire [B_WIDTH-2:0] final_shift_mem_in;
    wire [B_WIDTH-1:0] poly_final_shift;

    wire final_reverse_wren [1:0];
    wire [LOGSWORDS-1:0] final_reverse_addr [1:0];
    wire [B_WIDTH-1:0] final_reverse_din [1:0];
 
        
    initial begin
        $display("SERIAL_STAGES_FG_RV: %d", SERIAL_STAGES_FG_RV);
        $display("PIPELINE_STAGES_FG_RV: %d", PIPELINE_STAGES_FG_RV);
        
        $display("ITERATIONS DELTA: %d", ITERATIONS_DELTA);
        $display("ITERATIONS: %d", ITERATIONS);
        
        $display("PIPELINE_STAGES_REMAINDER: %d", PIPELINE_STAGES_REMAINDER);
        $display("Remainder: %d", REMAINDER);
    end
        
            
    // Description //////////////////////////////////////////////////////////////
    
    // Memory 
    always @(*) begin
        mem_rden[0]     = 1'b0;
        mem_wren[0]     = 1'b0;
        mem_addr[0]     = {LOGSWORDS{1'b0}};
        mem_dout[0]     = {B_WIDTH{1'b0}};
        
        mem_rden[1]     = 1'b0;
        mem_wren[1]     = 1'b0;
        mem_addr[1]     = {LOGSWORDS{1'b0}};
        mem_dout[1]     = {B_WIDTH{1'b0}};
        
        mem_rden[2]     = 1'b0;
        mem_wren[2]     = 1'b0;
        mem_addr[2]     = {LOGSWORDS{1'b0}};
        mem_dout[2]     = {B_WIDTH{1'b0}};
        
        mem_rden[3]     = 1'b0;
        mem_wren[3]     = 1'b0;
        mem_addr[3]     = {LOGSWORDS{1'b0}};
        mem_dout[3]     = {B_WIDTH{1'b0}};

        mem_rden[4]     = 1'b0;
        mem_wren[4]     = 1'b0;
        mem_addr[4]     = {LOGSWORDS{1'b0}};
        mem_dout[4]     = {B_WIDTH{1'b0}};
        
        mem_rden[5]     = 1'b0;
        mem_wren[5]     = 1'b0;
        mem_addr[5]     = {LOGSWORDS{1'b0}};
        mem_dout[5]     = {B_WIDTH{1'b0}};

        mem_rden[6]     = 1'b0;
        mem_wren[6]     = 1'b0;
        mem_addr[6]     = {LOGSWORDS{1'b0}};
        mem_dout[6]     = {B_WIDTH{1'b0}};

        mem_rden[7]     = 1'b0;
        mem_wren[7]     = 1'b0;
        mem_addr[7]     = {LOGSWORDS{1'b0}};
        mem_dout[7]     = {B_WIDTH{1'b0}};
                        
        case (memory_selection[0])
            // bitreverse
            2'b01: begin
                mem_rden[0]     = 1'b1;
                mem_wren[0]     = 1'b0;
                mem_addr[0]     = cnt_dec0_out;
                mem_dout[0]     = {B_WIDTH{1'b0}};
            end
            // iterations
            2'b11: begin
                mem_rden[0]     = iteration_rden[0];
                mem_wren[0]     = iteration_wren[0];
                mem_addr[0]     = iteration_addr[0];
                mem_dout[0]     = iteration_dout[0];
            end
        endcase

        case (memory_selection[1])
            // bitreverse
            2'b01: begin
                mem_rden[1]     = 1'b1;
                mem_wren[1]     = 1'b1;
                mem_addr[1]     = cnt_inc0_out;
                mem_dout[1]     = word_reversed;
            end
            // iterations
            2'b11: begin
                mem_rden[1]     = iteration_rden[1];
                mem_wren[1]     = iteration_wren[1];
                mem_addr[1]     = iteration_addr[1];
                mem_dout[1]     = iteration_dout[1];
            end
        endcase
                        
        case (memory_selection[2])
            // Initialization
            2'b01: begin
                mem_rden[2]     = 1'b1;
                mem_wren[2]     = 1'b1;
                mem_addr[2]     = {LOGSWORDS{1'b0}};
                mem_dout[2]     = {{B_WIDTH-1{1'b0}} , 1'b1};
            end
            2'b10: begin
                mem_rden[2]     = 1'b1;
                mem_wren[2]     = 1'b1;
                mem_addr[2]     = SWORDS-1;
                mem_dout[2]     = {{B_WIDTH-1-OVERHANG{1'b0}}, 1'b1 , {OVERHANG{1'b0}}};
            end
            // iterations
            2'b11: begin
                mem_rden[2]     = iteration_rden[2];
                mem_wren[2]     = iteration_wren[2];
                mem_addr[2]     = iteration_addr[2];
                mem_dout[2]     = iteration_dout[2];
            end  
        endcase

        case (memory_selection[3])
            // iterations
            2'b11: begin
                mem_rden[3]     = iteration_rden[3];
                mem_wren[3]     = iteration_wren[3];
                mem_addr[3]     = iteration_addr[3];
                mem_dout[3]     = iteration_dout[3];
            end
        endcase
                
        case (memory_selection[4])
            // Initialization
            2'b01: begin
                mem_rden[4]     = 1'b1;
                mem_wren[4]     = 1'b1;
                mem_addr[4]     = {LOGSWORDS{1'b0}};
                mem_dout[4]     = {{B_WIDTH-1{1'b0}} , 1'b1};
            end  
            // iterations
            2'b11: begin
                mem_rden[4]     = iteration_rden[4];
                mem_wren[4]     = iteration_wren[4];
                mem_addr[4]     = iteration_addr[4];
                mem_dout[4]     = iteration_dout[4];
            end        
        endcase

        case (memory_selection[5])
            // bitreverse
            2'b01: begin
                mem_rden[5]     = 1'b1;
                mem_wren[5]     = final_reverse_wren[0];
                mem_addr[5]     = final_reverse_addr[0];
                mem_dout[5]     = final_reverse_din[0];
            end
            // final shift
            2'b10: begin
                mem_rden[5]     = 1'b1;
                mem_wren[5]     = final_shift_wren[0];
                mem_addr[5]     = final_shift_addr[0];
                mem_dout[5]     = final_shift_din[0];
            end        
            // iterations
            2'b11: begin
                mem_rden[5]     = iteration_rden[5];
                mem_wren[5]     = iteration_wren[5];
                mem_addr[5]     = iteration_addr[5];
                mem_dout[5]     = iteration_dout[5];
            end        
        endcase  

        case (memory_selection[6])    
            // iterations
            2'b11: begin
                mem_rden[6]     = iteration_rden[6];
                mem_wren[6]     = iteration_wren[6];
                mem_addr[6]     = iteration_addr[6];
                mem_dout[6]     = iteration_dout[6];
            end        
        endcase      
        
        case (memory_selection[7])
            // bitreverse
            2'b01: begin
                mem_rden[7]     = 1'b1;
                mem_wren[7]     = final_reverse_wren[1];
                mem_addr[7]     = final_reverse_addr[1];
                mem_dout[7]     = final_reverse_din[1];
            end
            // final shift
            2'b10: begin
                mem_rden[7]     = 1'b1;
                mem_wren[7]     = final_shift_wren[1];
                mem_addr[7]     = final_shift_addr[1];
                mem_dout[7]     = final_shift_din[1];
            end   
            // iterations
            2'b11: begin
                mem_rden[7]     = iteration_rden[7];
                mem_wren[7]     = iteration_wren[7];
                mem_addr[7]     = iteration_addr[7];
                mem_dout[7]     = iteration_dout[7];
            end        
        endcase              
    end
    
    // Final shift
    assign final_shift_mem_in = (ITERATIONS[0] == 1'b1) ? mem_din[5][B_WIDTH-1:1] : mem_din[7][B_WIDTH-1:1];
    assign poly_final_shift = (cnt_dec1_out == SWORDS-2) ? {1'b0, final_shift_mem_in} : {reg_shift_right, final_shift_mem_in};
    
    generate 
        if(ITERATIONS[0]) begin
            assign final_shift_wren[0] = 1'b0;
            assign final_shift_wren[1] = cnt_inc0_enable;
            assign final_shift_addr[0] = cnt_dec1_out;
            assign final_shift_addr[1] = (cnt_dec1_out == SWORDS-1) ? 0 : cnt_dec1_out+1;
            assign final_shift_din[0] = {B_WIDTH{1'b0}};
            assign final_shift_din[1] = poly_final_shift;
        end
        else begin
            assign final_shift_wren[1] = 1'b0;
            assign final_shift_wren[0] = cnt_inc0_enable;
            assign final_shift_addr[1] = cnt_dec1_out;
            assign final_shift_addr[0] = (cnt_dec1_out == SWORDS-1) ? 0 : cnt_dec1_out+1;
            assign final_shift_din[1] = {B_WIDTH{1'b0}};
            assign final_shift_din[0] = poly_final_shift;        
        end
    endgenerate
    
    // Final bitreverse
    generate 
        if(ITERATIONS[0]) begin
            assign final_reverse_wren[1] = 1'b0;
            assign final_reverse_wren[0] = cnt_inc0_enable;
            assign final_reverse_addr[1] = cnt_dec0_out;
            assign final_reverse_addr[0] = cnt_inc0_out;
            assign final_reverse_din[1] = {B_WIDTH{1'b0}};
            assign final_reverse_din[0] = word_reversed; 
        end
        else begin
            assign final_reverse_wren[0] = 1'b0;
            assign final_reverse_wren[1] = cnt_inc0_enable;
            assign final_reverse_addr[0] = cnt_dec0_out;
            assign final_reverse_addr[1] = cnt_inc0_out;
            assign final_reverse_din[0] = {B_WIDTH{1'b0}};
            assign final_reverse_din[1] = word_reversed;       
        end
    endgenerate
    
    assign reg_shift_right_in = (ITERATIONS[0] == 1'b1) ? mem_din[5][0] : mem_din[7][0];
    always @(posedge clk) begin
        if(~resetn) begin
            reg_shift_right <= 'b0;
        end
        else begin
            if(final_shift) begin
                reg_shift_right <= reg_shift_right_in;
            end       
        end
    end
    
    
    // Bitreverse
    generate
        if(ITERATIONS[0]) begin
            assign overhang_reg_in = (final_shift == 1'b1) ? mem_din[7][OVERHANG-1:0] : mem_din[0][OVERHANG-1:0];
        end
        else begin
            assign overhang_reg_in = (final_shift == 1'b1) ? mem_din[5][OVERHANG-1:0] : mem_din[0][OVERHANG-1:0];
        end
    endgenerate

    RegisterFDRE #(.SIZE(OVERHANG))
    overhang_register(.clk(clk), .resetn(overhang_reg_resetn), .enable(overhang_reg_enable), .d(overhang_reg_in), .q(overhang_reg));
    
    generate
        for(genvar i=0; i<OVERHANG; i=i+1) begin
            assign word_reversed[i] = overhang_reg[OVERHANG-1-i]; 
        end
        for(genvar j=OVERHANG; j<B_WIDTH; j=j+1) begin
            assign word_reversed[j] = (final_shift == 1'b1) ? (ITERATIONS[0] == 1'b1) ? mem_din[7][B_WIDTH-1-(j-OVERHANG)] : mem_din[5][B_WIDTH-1-(j-OVERHANG)] : mem_din[0][B_WIDTH-1-(j-OVERHANG)];
        end
    endgenerate
    
    
    // Iterations
    // Determine swap
    assign iteration_rden[0] = (swap_rden == 1'b1) ? 1'b1 :(it_rden == 1'b1) ? 1'b1: 1'b0;
    assign iteration_wren[0] = (it_wren == 1'b1) ? ~track_poly : 1'b0;
    assign iteration_addr[0] = (swap_rden == 1'b1) ? 'b0 : (track_poly == 1'b0) ? addr_g_f : cnt_inc1_out;
    assign iteration_dout[0] = (track_poly == 1'b0) ? g_new : 'b0;
    
    assign iteration_rden[1] = (swap_rden == 1'b1) ? 1'b1 : (it_rden == 1'b1) ? 1'b1 : 1'b0;
    assign iteration_wren[1] = (it_wren == 1'b1) ? track_poly : 1'b0;
    assign iteration_addr[1] = (swap_rden == 1'b1) ? 'b0 : (track_poly == 1'b1) ? addr_g_f : cnt_inc1_out;
    assign iteration_dout[1] = (track_poly == 1'b1) ? g_new : 'b0;
    
    assign iteration_rden[2] = (swap_rden == 1'b1) ? 1'b1 : (it_rden == 1'b1) ? 1'b1 : 1'b0;
    assign iteration_wren[2] = (it_wren == 1'b1) ? track_poly : 1'b0;
    assign iteration_addr[2] = (swap_rden == 1'b1) ? 'b0 : (track_poly == 1'b1) ? addr_g_f : cnt_inc1_out;
    assign iteration_dout[2] = (track_poly == 1'b1) ? f_new : 'b0;

    assign iteration_rden[3] = (swap_rden == 1'b1) ? 1'b1 : (it_rden == 1'b1) ? 1'b1 : 1'b0;
    assign iteration_wren[3] = (it_wren == 1'b1) ? ~track_poly : 1'b0;
    assign iteration_addr[3] = (swap_rden == 1'b1) ? 'b0 : (track_poly == 1'b0) ? addr_g_f : cnt_inc1_out;
    assign iteration_dout[3] = (track_poly == 1'b0) ? f_new : 'b0;

    assign iteration_rden[4] = it_rden; 
    assign iteration_wren[4] = (it_wren == 1'b1) ? track_poly : 1'b0;
    assign iteration_addr[4] = (track_poly == 1'b1) ? addr_r_v : cnt_inc1_out-1;
    assign iteration_dout[4] = (track_poly == 1'b1) ? r_new : 'b0;

    assign iteration_rden[5] = it_rden; 
    assign iteration_wren[5] = (it_wren == 1'b1) ? track_poly : 1'b0;
    assign iteration_addr[5] = (track_poly == 1'b1) ? addr_r_v : cnt_inc1_out-1;
    assign iteration_dout[5] = (track_poly == 1'b1) ? v_new: 'b0;
    
    assign iteration_rden[6] = it_rden; 
    assign iteration_wren[6] = (it_wren == 1'b1) ? ~track_poly : 1'b0;
    assign iteration_addr[6] = (track_poly == 1'b0) ? addr_r_v : cnt_inc1_out-1;
    assign iteration_dout[6] = (track_poly == 1'b0) ? r_new : 'b0;       

    assign iteration_rden[7] = it_rden; 
    assign iteration_wren[7] = (it_wren == 1'b1) ? ~track_poly : 1'b0;
    assign iteration_addr[7] = (track_poly == 1'b0) ? addr_r_v : cnt_inc1_out-1;
    assign iteration_dout[7] = (track_poly == 1'b0) ? v_new : 'b0; 
    
    assign g_new = reg_g_in[PIPELINE_STAGES_FG_RV-1][B_WIDTH-1:0]; 
    assign f_new = reg_f_in[PIPELINE_STAGES_FG_RV-1][B_WIDTH-1:0]; 
    generate
        if((REMAINDER%SERIAL_STAGES_FG_RV) == 0 && REMAINDER != 0) begin
            assign r_new = (remainder_enable == 1'b1) ? reg_r_in[PIPELINE_STAGES_REMAINDER-1][B_WIDTH+STEPS-1:STEPS] : reg_r_in[PIPELINE_STAGES_FG_RV-1][B_WIDTH+STEPS-1:STEPS];
            assign v_new = (remainder_enable == 1'b1) ? reg_v_in[PIPELINE_STAGES_REMAINDER-1][B_WIDTH+STEPS-1:STEPS] : reg_v_in[PIPELINE_STAGES_FG_RV-1][B_WIDTH+STEPS-1:STEPS];  
        end
        else begin
            assign r_new = (remainder_enable == 1'b1) ? r_steps[REMAINDER][B_WIDTH+STEPS-1:STEPS] : reg_r_in[PIPELINE_STAGES_FG_RV-1][B_WIDTH+STEPS-1:STEPS];
            assign v_new = (remainder_enable == 1'b1) ? v_steps[REMAINDER][B_WIDTH+STEPS-1:STEPS] : reg_v_in[PIPELINE_STAGES_FG_RV-1][B_WIDTH+STEPS-1:STEPS];         
        end
    endgenerate
  
    
    assign addr_r_v = (remainder_enable == 1'b1) ? cnt_inc1_out-(1+PIPELINE_STAGES_REMAINDER) : cnt_inc1_out-(1+PIPELINE_STAGES_FG_RV); 
    assign addr_g_f = (remainder_enable == 1'b1) ? cnt_inc1_out-(1+PIPELINE_STAGES_REMAINDER) : cnt_inc1_out-(1+PIPELINE_STAGES_FG_RV); 
        
        
        
    
    // Control bits /////////////////////////////////////////////////////////////    
    // control_bit register    
    generate
        for(genvar i=0; i<ITERATIONS_DELTA; i=i+1) begin
            if(i == ITERATIONS_DELTA-1 && (STEPS%UNROLLING_DELTA) != 0) begin
//                assign control_bits_in[((STEPS%UNROLLING_DELTA)*2*(i+1)-1):((STEPS%UNROLLING_DELTA)*2*i)] = (cnt_inc0_out == i) ? control_bits_batch_in[(STEPS%UNROLLING_DELTA)*2-1:0] : control_bits[((STEPS%UNROLLING_DELTA)*2*(i+1)-1):((STEPS%UNROLLING_DELTA)*2*i)];
                assign control_bits_in[(UNROLLING_DELTA*2*i-1)+2*(STEPS%UNROLLING_DELTA):(UNROLLING_DELTA*2*i)] = (cnt_inc0_out == i) ? control_bits_batch_in[(STEPS%UNROLLING_DELTA)*2-1:0] : control_bits[(UNROLLING_DELTA*2*i-1)+2*(STEPS%UNROLLING_DELTA):(UNROLLING_DELTA*2*i)];
            end
            else begin
                assign control_bits_in[(UNROLLING_DELTA*2*(i+1)-1):(UNROLLING_DELTA*2*i)] = (cnt_inc0_out == i) ? control_bits_batch_in : control_bits[(UNROLLING_DELTA*2*(i+1)-1):(UNROLLING_DELTA*2*i)];
            end
        end
    endgenerate
    
    always @(posedge clk) begin
        if(~resetn) begin
            control_bits <= {2*STEPS{1'b0}};
        end
        else begin
            if(swap_en) begin
                control_bits <= control_bits_in;
            end
            else begin
                control_bits <= control_bits;
            end
        end
    end
    
    always @(*) begin
        f0 = {STEPS{1'b0}};
        g0 = {STEPS{1'b0}};
        
        case(track_poly)
            1'b0: f0 = mem_din[2][STEPS-1:0];
            1'b1: f0 = mem_din[3][STEPS-1:0];
        endcase
        
        case(track_poly)
            1'b0: g0 = mem_din[1][STEPS-1:0];
            1'b1: g0 = mem_din[0][STEPS-1:0];
        endcase
    end
    
    assign g0_iter[0] = (cnt_inc0_out == 0) ? g0 : g0_iter_reg;
    assign f0_iter[0] = (cnt_inc0_out == 0) ? f0 : f0_iter_reg;
    assign delta_in[0] = delta;
    
    generate
        for(genvar s=0; s<UNROLLING_DELTA; s=s+1) begin
            assign f0g0[s] = g0_iter[s][0];
            assign swap_bit[s] = ((delta_in[s][B_WIDTH-1] == 1'b0) && (delta_in[s] != 0)) ? f0g0[s] : 1'b0;
            
            assign control_bits_batch_in[2*s] = swap_bit[s]; 
            assign control_bits_batch_in[2*s+1] = f0g0[s]; 
            
            assign delta_neg[s] = (~delta_in[s]) + 1;
            assign delta_in[s+1] = (swap_bit[s] == 1'b1) ? delta_neg[s]+1 : delta_in[s]+1;
            
            assign f0_iter[s+1] = (swap_bit[s] == 1'b1) ? g0_iter[s] : f0_iter[s];
            assign f_and_f0g0[s] = (f0g0[s] == 1'b1) ? f0_iter[s][STEPS-1:1] : {(STEPS-1){1'b0}};
            assign g0_iter[s+1] = {1'b0, g0_iter[s][STEPS-1:1] ^ f_and_f0g0[s]};        
        end
    endgenerate 

    // f0 and g0 iter register    
    always @(posedge clk) begin
        if(~resetn) begin
            g0_iter_reg <= 'b0;
            f0_iter_reg <= 'b0;
        end
        else begin
            if(swap_en) begin
                g0_iter_reg <= g0_iter[UNROLLING_DELTA];
                f0_iter_reg <= f0_iter[UNROLLING_DELTA];
            end
            else begin
                g0_iter_reg <= g0_iter_reg;
                f0_iter_reg <= f0_iter_reg;
            end
        end    
    end    
    
    // delta register
    generate
        if((STEPS % UNROLLING_DELTA) == 0) begin
            assign delta_reg_in = delta_in[UNROLLING_DELTA];
        end
        else begin
            assign delta_reg_in = (cnt_inc0_out == ITERATIONS_DELTA-1) ? delta_in[STEPS%UNROLLING_DELTA] : delta_in[UNROLLING_DELTA];
        end
    endgenerate
    
    always @(posedge clk) begin
        if(~resetn) begin
            delta <= 1;
        end
        else begin
            if(swap_en) begin
                delta <= delta_reg_in;
            end
            else begin
                delta <= delta;
            end
        end    
    end    
    /////////////////////////////////////////////////////////////////////////////
    
    
    
    // Conditional add and shift ////////////////////////////////////////////////
    always @ (*) begin
        poly_g = 'b0;
        poly_f = 'b0;
        poly_r = 'b0;
        poly_v = 'b0;
        
        case(track_poly)
            1'b0: poly_g = mem_din[1];
            1'b1: poly_g = mem_din[0];
        endcase

        case(track_poly)
            1'b0: poly_f = mem_din[2];
            1'b1: poly_f = mem_din[3];
        endcase    
        
        case(track_poly)
            1'b0: poly_r = mem_din[4];
            1'b1: poly_r = mem_din[6];
        endcase  
        
        case(track_poly)
            1'b0: poly_v = mem_din[5];
            1'b1: poly_v = mem_din[7];
        endcase     
    end
    
    // Buffer f, g, r, and v
    always @(posedge clk) begin
        if(~resetn) begin
            poly_f_reg <= {B_WIDTH{1'b0}};
            poly_g_reg <= {B_WIDTH{1'b0}};
            poly_r_reg <= {B_WIDTH{1'b0}};
            poly_v_reg <= {B_WIDTH{1'b0}};
        end
        else begin
            poly_f_reg <= poly_f;
            poly_g_reg <= poly_g;
            poly_r_reg <= poly_r;
            poly_v_reg <= poly_v;
        end
    end
    
    // assign f and g
    assign f_steps[0] = {poly_f[STEPS-1:0], poly_f_reg};
    assign g_steps[0] = {poly_g[STEPS-1:0], poly_g_reg};
    
    generate 
        for(genvar p=0; p<PIPELINE_STAGES_FG_RV; p=p+1) begin
            if(p == (PIPELINE_STAGES_FG_RV-1) && (STEPS%SERIAL_STAGES_FG_RV) != 0) begin
                for(genvar s=0; s<(STEPS%SERIAL_STAGES_FG_RV)-1; s=s+1) begin
                    assign f_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s] == 1'b1) ? g_steps[p*SERIAL_STAGES_FG_RV+s] : f_steps[p*SERIAL_STAGES_FG_RV+s];
                    assign g_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s+1] == 1'b1) ? {1'b0, f_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-1:1] ^ g_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-1:1]} : {1'b0, g_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-1:1]};
                end  
                
                assign reg_f_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*((STEPS%SERIAL_STAGES_FG_RV)-1)] == 1'b1) ? g_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1] : f_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1];
                assign reg_g_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*((STEPS%SERIAL_STAGES_FG_RV)-1)+1] == 1'b1) ? {1'b0, f_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1][B_WIDTH+STEPS-1:1] ^ g_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1][B_WIDTH+STEPS-1:1]} : {1'b0, g_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1][B_WIDTH+STEPS-1:1]};          
            end
            else begin
                for(genvar s=0; s<SERIAL_STAGES_FG_RV-1; s=s+1) begin
                    assign f_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s] == 1'b1) ? g_steps[p*SERIAL_STAGES_FG_RV+s] : f_steps[p*SERIAL_STAGES_FG_RV+s];
                    assign g_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s+1] == 1'b1) ? {1'b0, f_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-1:1] ^ g_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-1:1]} : {1'b0, g_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-1:1]};
                end
                
                assign reg_f_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*(SERIAL_STAGES_FG_RV-1)] == 1'b1) ? g_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1] : f_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1];
                assign reg_g_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*(SERIAL_STAGES_FG_RV-1)+1] == 1'b1) ? {1'b0, f_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1][B_WIDTH+STEPS-1:1] ^ g_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1][B_WIDTH+STEPS-1:1]} : {1'b0, g_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1][B_WIDTH+STEPS-1:1]};                
            end
            
            // instantiate pipeline stage
            if(p != PIPELINE_STAGES_FG_RV-1) begin
                RegisterFDRE #(.SIZE(B_WIDTH+STEPS))
                reg_f (.clk(clk), .enable(enable), .resetn(resetn), .d(reg_f_in[p]), .q(f_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV]));
                
                RegisterFDRE #(.SIZE(B_WIDTH+STEPS))
                reg_g (.clk(clk), .enable(enable), .resetn(resetn), .d(reg_g_in[p]), .q(g_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV]));                               
            end
        end
    endgenerate    
    
    
    // assign r and v
    assign r_steps[0] = (cnt_inc1_out == 2) ? {poly_r, {STEPS{1'b0}}} : {poly_r, poly_r_reg[B_WIDTH-1:B_WIDTH-STEPS]};
    assign v_steps[0] = (cnt_inc1_out == 2) ? {poly_v, {STEPS{1'b0}}} : {poly_v, poly_v_reg[B_WIDTH-1:B_WIDTH-STEPS]};

    generate 
        for(genvar p=0; p<PIPELINE_STAGES_FG_RV; p=p+1) begin
            if(p == (PIPELINE_STAGES_FG_RV-1) && (STEPS%SERIAL_STAGES_FG_RV) != 0) begin
                for(genvar s=0; s<(STEPS%SERIAL_STAGES_FG_RV)-1; s=s+1) begin
                    assign v_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s] == 1'b1) ? {r_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-2:0], 1'b0} : {v_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-2:0], 1'b0};  
                    assign r_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s+1] == 1'b1) ? v_steps[p*SERIAL_STAGES_FG_RV+s] ^ r_steps[p*SERIAL_STAGES_FG_RV+s] : r_steps[p*SERIAL_STAGES_FG_RV+s];
                end   
                
                assign reg_v_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*((STEPS%SERIAL_STAGES_FG_RV)-1)] == 1'b1) ? {r_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1][B_WIDTH+STEPS-2:0], 1'b0} : {v_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1][B_WIDTH+STEPS-2:0], 1'b0};  
                assign reg_r_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*((STEPS%SERIAL_STAGES_FG_RV)-1)+1] == 1'b1) ? v_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1] ^ r_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1] : r_steps[p*SERIAL_STAGES_FG_RV+(STEPS%SERIAL_STAGES_FG_RV)-1];         
            end
            else begin
                for(genvar s=0; s<SERIAL_STAGES_FG_RV-1; s=s+1) begin
                    assign v_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s] == 1'b1) ? {r_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-2:0], 1'b0} : {v_steps[p*SERIAL_STAGES_FG_RV+s][B_WIDTH+STEPS-2:0], 1'b0};  
                    assign r_steps[p*SERIAL_STAGES_FG_RV+s+1] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*s+1] == 1'b1) ? v_steps[p*SERIAL_STAGES_FG_RV+s] ^ r_steps[p*SERIAL_STAGES_FG_RV+s] : r_steps[p*SERIAL_STAGES_FG_RV+s];
                end
                
                assign reg_v_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*(SERIAL_STAGES_FG_RV-1)] == 1'b1) ? {r_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1][B_WIDTH+STEPS-2:0], 1'b0} : {v_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1][B_WIDTH+STEPS-2:0], 1'b0};  
                assign reg_r_in[p] = (control_bits[p*2*SERIAL_STAGES_FG_RV+2*(SERIAL_STAGES_FG_RV-1)+1] == 1'b1) ? v_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1] ^ r_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1] : r_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV-1];                       
            end
            
            // instantiate pipeline stage       
            if(p != PIPELINE_STAGES_FG_RV-1) begin
                RegisterFDRE #(.SIZE(B_WIDTH+STEPS))
                reg_v (.clk(clk), .enable(enable), .resetn(resetn), .d(reg_v_in[p]), .q(v_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV]));
                
                RegisterFDRE #(.SIZE(B_WIDTH+STEPS))
                reg_r (.clk(clk), .enable(enable), .resetn(resetn), .d(reg_r_in[p]), .q(r_steps[p*SERIAL_STAGES_FG_RV+SERIAL_STAGES_FG_RV]));                
            end
        end
    endgenerate    
   
    
    // tracking polynomials
    assign track_poly_in = track_poly ^ 1'b1; 
        
    always @(posedge clk) begin
        if(~resetn) begin
            track_poly <= 1'b0;
        end
        else begin
            if(tracking_en) begin
                track_poly <= track_poly_in;
            end
            else begin
                track_poly <= track_poly;
            end
        end
    end
    /////////////////////////////////////////////////////////////////////////////
    
    
    
    // Counter //////////////////////////////////////////////////////////////////
    // Used for bit reverse
    BIKE_counter_dec_init #(.SIZE(LOGSWORDS), .INIT(SWORDS-1), .MAX_VALUE(SWORDS-1))
    cnt_dec0 (.clk(clk), .enable(cnt_dec0_enable), .resetn(cnt_dec0_resetn), .cnt_out(cnt_dec0_out));
    
    assign cnt_inc0_done = (cnt_inc0_out == SWORDS-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE($clog2(CNT0_SIZE)), .MAX_VALUE(CNT0_SIZE+1))
    cnt_inc0 (.clk(clk), .enable(cnt_inc0_enable), .resetn(cnt_inc0_resetn), .cnt_out(cnt_inc0_out)); 

    // Counter for final shift
    BIKE_counter_dec_init #(.SIZE(LOGSWORDS), .INIT(0), .MAX_VALUE(SWORDS-1))
    cnt_dec1 (.clk(clk), .enable(cnt_dec1_enable), .resetn(cnt_dec1_resetn), .cnt_out(cnt_dec1_out));    

    // counter for f, g and r, v
    BIKE_mult_counter_inc_init #(.SIZE($clog2(SWORDS+PIPELINE_STAGES_FG_RV)), .INIT(0), .MAX_VALUE(SWORDS+PIPELINE_STAGES_FG_RV))
    cnt_inc1 (.clk(clk), .enable(cnt_inc1_enable), .resetn(cnt_inc1_resetn), .cnt_out(cnt_inc1_out));    

    // tracks entire progress    
    assign cnt_inc2_done = (cnt_inc2_out == div_and_floor(2*R_BITS-1, STEPS)+1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE($clog2(2*R_BITS)), .MAX_VALUE(2*R_BITS))
    cnt_inc2 (.clk(clk), .enable(cnt_inc2_enable), .resetn(cnt_inc2_resetn), .cnt_out(cnt_inc2_out));   
    /////////////////////////////////////////////////////////////////////////////
    
    
    // FINITE STATE MACHINE (FSM) ///////////////////////////////////////////////
    localparam [4:0]
        s_idle                      =  0,
        s_init0                     =  1,
        s_init1                     =  2,
        s_bitreverse_init0          =  3,
        s_bitreverse_init1          =  4,
        s_bitreverse                =  5,
        s_swap_init                 =  6,
        s_swap                      =  7,
        s_add_shift_init            =  8,
        s_add_shift                 =  9,
        s_add_shift_remainder_init  = 10,
        s_add_shift_remainder       = 11,
        s_update_tracking           = 12,
        s_final_shift_init0         = 13,
        s_final_shift_init1         = 14,
        s_final_shift               = 15,
        s_reset_counter             = 16,
        s_final_bitreverse_init0    = 17,
        s_final_bitreverse_init1    = 18,
        s_final_bitreverse          = 19,
        s_done                      = 20;

        
    reg [4:0] state_reg, state_next;
    
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
                    state_next      = s_init0;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_init0 : begin
                state_next          = s_init1;
            end
            // -----------------------------------

            // -----------------------------------
            s_init1 : begin
                state_next          = s_bitreverse_init0;
            end
            // -----------------------------------

            // -----------------------------------
            s_bitreverse_init0 : begin
                state_next          = s_bitreverse_init1;
            end
            // -----------------------------------

            // -----------------------------------
            s_bitreverse_init1 : begin
                state_next          = s_bitreverse;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_bitreverse : begin
                if(cnt_inc0_done) begin
                    state_next      = s_swap_init;
                end
                else begin                
                    state_next      = s_bitreverse;
                end                
            end
            // -----------------------------------

            // -----------------------------------
            s_swap_init : begin
                state_next          = s_swap;
            end
            // -----------------------------------

            // -----------------------------------
            s_swap : begin
                if(cnt_inc0_out == ITERATIONS_DELTA-1) begin
                    if(cnt_inc2_done) begin
                        state_next  = s_add_shift_remainder_init;
                    end
                    else begin
                        state_next  = s_add_shift_init;
                    end
                end
                else begin
                    state_next      = s_swap;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_add_shift_init : begin
                if(cnt_inc1_out == PIPELINE_STAGES_FG_RV) begin
                    state_next      = s_add_shift;
                end
                else begin
                    state_next      = s_add_shift_init;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_add_shift : begin
                if(cnt_inc0_done) begin
                    state_next      = s_update_tracking;
                end
                else begin
                    state_next      = s_add_shift;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_add_shift_remainder_init : begin
                if(cnt_inc1_out == PIPELINE_STAGES_REMAINDER) begin
                    state_next      = s_add_shift_remainder;
                end
                else begin
                    state_next      = s_add_shift_remainder_init;
                end
            end
            // -----------------------------------
            
            // -----------------------------------
            s_add_shift_remainder : begin
                if(cnt_inc0_done) begin
                    state_next      = s_final_shift_init0;
                end
                else begin
                    state_next      = s_add_shift_remainder;
                end
            end
            // -----------------------------------
            
            // -----------------------------------
            s_update_tracking : begin
                state_next      = s_swap_init;
            end
            // -----------------------------------

            // -----------------------------------
            s_final_shift_init0 : begin
                state_next          = s_final_shift_init1;
            end
            // -----------------------------------

            // -----------------------------------
            s_final_shift_init1 : begin
                state_next          = s_final_shift;
            end
            // -----------------------------------

            // -----------------------------------
            s_final_shift : begin
                if(cnt_inc0_done) begin
                    state_next      = s_reset_counter;
                end
                else begin
                    state_next      = s_final_shift;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_reset_counter : begin
                state_next          = s_final_bitreverse_init0;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_final_bitreverse_init0 : begin
                state_next          = s_final_bitreverse_init1;
            end
            // -----------------------------------

            // -----------------------------------
            s_final_bitreverse_init1 : begin
                state_next          = s_final_bitreverse;
            end
            // -----------------------------------
 
             // -----------------------------------
            s_final_bitreverse : begin
                if(cnt_inc0_done) begin
                    state_next      = s_done;
                end
                else begin
                    state_next      = s_final_bitreverse;
                end
            end
            // -----------------------------------
                                                                                                                                                                                                           
            // -----------------------------------
            s_done : begin
                if(~resetn) begin   
                    state_next      = s_idle;
                end 
                else begin 
                    state_next      = s_done;
                end
            end
            // -----------------------------------                                  
         endcase     
    end
    
    // output logic
    always @(state_reg) begin
        // default outputs
        // Global control
        done                        = 1'b0;
        
        // Memory selection
        memory_selection[0]         = 2'b00;
        memory_selection[1]         = 2'b00;
        memory_selection[2]         = 2'b00;
        memory_selection[3]         = 2'b00;
        memory_selection[4]         = 2'b00;
        memory_selection[5]         = 2'b00;
        memory_selection[6]         = 2'b00;
        memory_selection[7]         = 2'b00;
        
        // Counter
        cnt_dec0_enable             = 1'b0;
        cnt_dec0_resetn             = 1'b0;
        
        cnt_inc0_enable             = 1'b0;
        cnt_inc0_resetn             = 1'b0;

        cnt_inc1_enable             = 1'b0;
        cnt_inc1_resetn             = 1'b0;

        cnt_dec1_enable             = 1'b0;
        cnt_dec1_resetn             = 1'b0;
                
        cnt_inc2_enable             = 1'b0;
        cnt_inc2_resetn             = 1'b0;
                
        // Register
        overhang_reg_enable         = 1'b0;
        overhang_reg_resetn         = 1'b0;
        
        // Swap, Delta, f0g0
        swap_rden                   = 1'b0;
        swap_en                     = 1'b0;
        
        // Iteration
        it_rden                     = 1'b0;
        it_wren                     = 1'b0;
        
        tracking_en                 = 1'b0;
        
        remainder_enable            = 1'b0;
        
        // Final shift
        final_shift                 = 1'b0;
        
        case (state_reg)
            // -----------------------------------
            s_idle : begin

            end
            // -----------------------------------

            // -----------------------------------
            s_init0 : begin
                memory_selection[2]         = 2'b01;
                memory_selection[4]         = 2'b01;
            end
            // -----------------------------------

            // -----------------------------------
            s_init1 : begin
                memory_selection[2]         = 2'b10;
            end
            // -----------------------------------

            // -----------------------------------
            s_bitreverse_init0 : begin
                memory_selection[0]         = 2'b01;
                
                cnt_dec0_enable             = 1'b1;
                cnt_dec0_resetn             = 1'b1;
                
                overhang_reg_enable         = 1'b1;
                overhang_reg_resetn         = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_bitreverse_init1 : begin
                memory_selection[0]         = 2'b01;
                
                cnt_dec0_enable             = 1'b1;
                cnt_dec0_resetn             = 1'b1;
                
                overhang_reg_enable         = 1'b1;
                overhang_reg_resetn         = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_bitreverse : begin
                memory_selection[0]         = 2'b01;
                memory_selection[1]         = 2'b01;
                
                cnt_dec0_enable             = 1'b1;
                cnt_dec0_resetn             = 1'b1;
                
                cnt_inc0_enable             = 1'b1;
                cnt_inc0_resetn             = 1'b1;       
                
                overhang_reg_enable         = 1'b1;
                overhang_reg_resetn         = 1'b1;                         
            end
            // -----------------------------------
            
            // -----------------------------------
            s_swap_init : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                
                cnt_inc2_enable             = 1'b1;                    
                cnt_inc2_resetn             = 1'b1;   
                
                swap_rden                   = 1'b1;                 
            end
            // -----------------------------------            

            // -----------------------------------
            s_swap : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                                   
                cnt_inc0_enable             = 1'b1;                   
                cnt_inc0_resetn             = 1'b1;                   
                                   
                cnt_inc2_resetn             = 1'b1;   
                
                swap_en                     = 1'b1;                 
            end
            // ----------------------------------- 

            // -----------------------------------
            s_add_shift_init : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                memory_selection[4]         = 2'b11; 
                memory_selection[5]         = 2'b11; 
                memory_selection[6]         = 2'b11;
                memory_selection[7]         = 2'b11;

                cnt_inc1_resetn             = 1'b1;
                cnt_inc1_enable             = 1'b1;                                                             
                
                cnt_inc2_resetn             = 1'b1;         
                
                it_rden                     = 1'b1;          
            end
            // ----------------------------------- 
            
            // -----------------------------------
            s_add_shift : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                memory_selection[4]         = 2'b11; 
                memory_selection[5]         = 2'b11; 
                memory_selection[6]         = 2'b11; 
                memory_selection[7]         = 2'b11; 

                cnt_inc0_resetn             = 1'b1;
                cnt_inc0_enable             = 1'b1;
                
                cnt_inc1_resetn             = 1'b1;
                cnt_inc1_enable             = 1'b1;
                
                cnt_inc2_resetn             = 1'b1;         
                
                it_rden                     = 1'b1;                    
                it_wren                     = 1'b1;                                       
            end
            // ----------------------------------- 

            // -----------------------------------
            s_add_shift_remainder_init : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                memory_selection[4]         = 2'b11; 
                memory_selection[5]         = 2'b11; 
                memory_selection[6]         = 2'b11;
                memory_selection[7]         = 2'b11;

                cnt_inc1_resetn             = 1'b1;
                cnt_inc1_enable             = 1'b1;                                                             
                
                cnt_inc2_resetn             = 1'b1;         
                
                it_rden                     = 1'b1;          
            end
            // ----------------------------------- 
            
            // -----------------------------------
            s_add_shift_remainder : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                memory_selection[4]         = 2'b11; 
                memory_selection[5]         = 2'b11; 
                memory_selection[6]         = 2'b11; 
                memory_selection[7]         = 2'b11; 

                cnt_inc0_resetn             = 1'b1;
                cnt_inc0_enable             = 1'b1;
                
                cnt_inc1_resetn             = 1'b1;
                cnt_inc1_enable             = 1'b1;

                cnt_inc2_resetn             = 1'b1;         
                
                it_rden                     = 1'b1;                    
                it_wren                     = 1'b1;    
                
                remainder_enable            = 1'b1;                                   
            end
            // ----------------------------------- 
            
            // -----------------------------------
            s_update_tracking : begin
                memory_selection[0]         = 2'b11; 
                memory_selection[1]         = 2'b11; 
                memory_selection[2]         = 2'b11; 
                memory_selection[3]         = 2'b11; 
                memory_selection[4]         = 2'b11; 
                memory_selection[5]         = 2'b11; 
                memory_selection[6]         = 2'b11; 
                memory_selection[7]         = 2'b11; 
                
                cnt_inc2_resetn             = 1'b1;         
                
                tracking_en                 = 1'b1;                
            end
            // ----------------------------------- 

            // -----------------------------------
            s_final_shift_init0 : begin
                memory_selection[5]         = 2'b10; 
                memory_selection[7]         = 2'b10; 

                cnt_dec1_resetn             = 1'b1;
                cnt_dec1_enable             = 1'b1;
                                
                final_shift                 = 1'b1;               
            end
            // ----------------------------------- 

            // -----------------------------------
            s_final_shift_init1 : begin
                memory_selection[5]         = 2'b10; 
                memory_selection[7]         = 2'b10; 

                cnt_dec1_resetn             = 1'b1;
                cnt_dec1_enable             = 1'b1;
                                
                final_shift                 = 1'b1;               
            end
            // ----------------------------------- 

            // -----------------------------------
            s_final_shift : begin
                memory_selection[5]         = 2'b10; 
                memory_selection[7]         = 2'b10; 
                
                cnt_inc0_resetn             = 1'b1;
                cnt_inc0_enable             = 1'b1;
                
                cnt_dec1_resetn             = 1'b1;
                cnt_dec1_enable             = 1'b1;
                                
                final_shift                 = 1'b1;               
            end
            // -----------------------------------
            
            // -----------------------------------
            s_final_bitreverse_init0 : begin
                memory_selection[5]         = 2'b01;
                memory_selection[7]         = 2'b01;  
                
                cnt_dec0_enable             = 1'b1;
                cnt_dec0_resetn             = 1'b1;
                
                overhang_reg_enable         = 1'b1;
                overhang_reg_resetn         = 1'b1; 
                
                final_shift                 = 1'b1;   
            end
            // -----------------------------------            

            // -----------------------------------
            s_final_bitreverse_init1 : begin
                memory_selection[5]         = 2'b01; 
                memory_selection[7]         = 2'b01;
                
                cnt_dec0_enable             = 1'b1;
                cnt_dec0_resetn             = 1'b1;
                
                overhang_reg_enable         = 1'b1;
                overhang_reg_resetn         = 1'b1;  
                
                final_shift                 = 1'b1;   
            end
            // -----------------------------------   
            
            // -----------------------------------
            s_final_bitreverse : begin
                memory_selection[5]         = 2'b01;
                memory_selection[7]         = 2'b01;
                
                cnt_dec0_enable             = 1'b1;
                cnt_dec0_resetn             = 1'b1;
                
                cnt_inc0_enable             = 1'b1;
                cnt_inc0_resetn             = 1'b1;       
                
                overhang_reg_enable         = 1'b1;
                overhang_reg_resetn         = 1'b1;    
                
                final_shift                 = 1'b1;                           
            end
            // -----------------------------------
                                                                                                                                                                                                                                                                                                                                                                                             
            // -----------------------------------
            s_done : begin
                done                        = 1'b1;
            end
            // -----------------------------------
        endcase
    end
    //////////////////////////////////////////////////////////////////////////////    
        

endmodule