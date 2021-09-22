`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Ruhr-Universit�t Bochum
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         14.06.2021 
// Module Name:         BIKE_sparse_multiplier_hs
// Description:         Sparse polynomial multiplier for BIKE. Optimized critical path from memories to computation unit.
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



module BIKE_sparse_multiplier_hs #(
        parameter LOG_SIZE_HW = 7
    )(
        input  wire clk,
        input  wire resetn,
        input  wire enable,
        output reg  done,
        output wire valid,
        // Control Hamming weight
        input  wire [LOG_SIZE_HW-1:0] hw_sparse,
        // extra initial addition
        input  wire apply_init_addtion,
        output wire init_add_rden,
        output wire [LOGSWORDS-1:0] init_add_addr,
        input  wire [B_WIDTH-1:0] init_add_din, 
        // Vector (sparse)
        output reg  vec_rden,
        output reg  [LOGDWORDS-1:0] vec_addr,
        input  wire [31:0] vec_din,
        // Matrix (dense)
        output reg  mat_rden,
        output reg  [LOGSWORDS-1:0] mat_addr,
        input  wire [B_WIDTH-1:0] mat_din,
        // Result A
        output reg  resa_rden,
        output reg  resa_wren,
        output reg  [LOGSWORDS-1:0] resa_addr,
        output reg  [B_WIDTH-1:0] resa_dout,
        input  wire [B_WIDTH-1:0] resa_din,
        // Result B
        output reg  resb_rden,
        output reg  resb_wren,
        output reg  [LOGSWORDS-1:0] resb_addr,
        output reg  [B_WIDTH-1:0] resb_dout,
        input  wire [B_WIDTH-1:0] resb_din                         
    );
  
  
    
    // Registers and wires //////////////////////////////////////////////////////
    // Counter
    reg cnt_sparse_enable;
    reg cnt_sparse_resetn;
    wire cnt_sparse_done;
    wire [LOG_SIZE_HW-1:0] cnt_sparse_out;

    reg cnt_mat_enable;
    reg cnt_mat_resetn;
    wire [LOGSWORDS-1:0] cnt_mat_out;


    // Results
    reg sample_res_addr;
    reg res_addr_cnt_resetn;
    wire [LOGSWORDS-1:0] res_addr_cnt_in;
    wire [LOGSWORDS-1:0] res_addr_cnt_inc;
    reg [LOGSWORDS-1:0] res_addr_cnt;
    wire [LOGSWORDS-1:0] res_addr_cnt_dec;
    
    reg res_wren;
    wire [B_WIDTH-1:0] res_final_out;
    wire [B_WIDTH-1:0] res_xor_in;
    wire [B_WIDTH-1:0] res_xor;
    wire [B_WIDTH-1:0] res_xor_shift_in;
    reg [B_WIDTH-OVERHANG-1:0] res_xor_msbs;


    // Matrix    
    reg mat_reg_resetn;
    reg [1:0] mat_reg_in_sel;
    reg [B_WIDTH+B_WIDTH-2:0] mat_reg;
    reg [B_WIDTH+B_WIDTH-2:0] mat_reg_in;
    
    reg  shift_sel_resetn;
    reg  [LOGBWIDTH-1:0] shift_sel_reg;
    wire [LOGBWIDTH-1:0] shift_sel;
    wire [2*B_WIDTH-1:0] mat_shifted_hi [LOGBWIDTH:0];
    
    wire [2*B_WIDTH-1:0] mult_with_one_in;
    reg  mult_with_one;

    // wrapper
    reg wrapper_resetn;
    reg wrapper_fsm_enable;
    wire wrapper_enable;
    reg wrapper;
   
        
    initial begin
        $display("Setting up the sparse multiplier:");
    end
        
            
    // Description //////////////////////////////////////////////////////////////
    assign valid = (cnt_sparse_done == 1'b1) ? resa_wren | resb_wren : 1'b0;

    // Memory interface to (sparse) vector
    assign vec_addr = {{(LOGDWORDS-LOG_SIZE_HW){1'b0}}, cnt_sparse_out};
    
    
    // Memory interface to result
    assign res_addr_cnt_in = (sample_res_addr == 1'b1) ? vec_din[LOGRBITS-1:LOGBWIDTH] : res_addr_cnt_inc;
    assign res_addr_cnt_inc = (res_addr_cnt == SWORDS-1) ? 'b0 : res_addr_cnt + 1;
    
    always @ (posedge clk) begin
        if(~res_addr_cnt_resetn) begin
            res_addr_cnt <= 'b0;
        end 
        else begin
            res_addr_cnt <= res_addr_cnt_in;
        end        
    end;
    assign res_addr_cnt_dec = (res_addr_cnt == {LOGSWORDS{1'b0}}) ? (SWORDS-1) : res_addr_cnt-1;

    assign init_add_rden = (cnt_sparse_out == 0) ? resa_rden : 1'b0;
    assign init_add_addr = res_addr_cnt;

    assign resa_wren = (cnt_sparse_out[0] == 1'b1) ? 1'b0 : res_wren;
    assign resb_wren = (cnt_sparse_out[0] == 1'b0) ? 1'b0 : res_wren;
    
    assign resa_addr = (cnt_sparse_out[0] == 1'b1) ? res_addr_cnt : res_addr_cnt_dec;
    assign resb_addr = (cnt_sparse_out[0] == 1'b0) ? res_addr_cnt : res_addr_cnt_dec;
    
    assign resa_dout = (cnt_sparse_out[0] == 1'b1) ? 'b0 : res_final_out;
    assign resb_dout = (cnt_sparse_out[0] == 1'b0) ? 'b0 : res_final_out;
    
    assign res_xor_in = (apply_init_addtion == 1'b1 && cnt_sparse_out == 0) ? init_add_din : (cnt_sparse_out[0] == 1'b1) ? resa_din : resb_din;
    assign res_xor_shift_in = (wrapper == 1'b1) ? {mat_shifted_hi[LOGBWIDTH][OVERHANG-1+B_WIDTH:B_WIDTH], res_xor_msbs} : mat_shifted_hi[LOGBWIDTH][2*B_WIDTH-1:B_WIDTH];
    assign res_xor = res_xor_in ^ res_xor_shift_in;
    assign res_final_out = (res_addr_cnt_dec == SWORDS-1) ? res_xor[OVERHANG-1:0] : res_xor;
    
    always @(posedge clk) begin
        if(~resetn) begin
            res_xor_msbs <= 'b0;
        end
        else begin
            res_xor_msbs <= mat_shifted_hi[LOGBWIDTH][2*B_WIDTH-1:B_WIDTH+OVERHANG];
        end
    end
    
    assign wrapper_enable = (res_addr_cnt_dec == SWORDS-1) ? wrapper_fsm_enable : 1'b0;
    always @(posedge clk) begin
        if(~wrapper_resetn) begin
            wrapper <= 1'b0;
        end
        else begin
            if(wrapper_enable) begin
                wrapper <= 1'b1;
            end
            else begin
                wrapper <= wrapper;
            end
        end
    end
        



    // buffer input data
    assign mat_addr = cnt_mat_out;
    
    always @(*) begin
        case(mat_reg_in_sel)
            2'b00 : mat_reg_in <= 'b0;
            2'b01 : mat_reg_in <= {{OVERHANG{1'b0}}, mat_din[B_WIDTH-1:OVERHANG+1], {B_WIDTH{1'b0}}};
            2'b10 : mat_reg_in <= {mat_din[OVERHANG-1:0], mat_reg[2*B_WIDTH-OVERHANG-2:B_WIDTH], {B_WIDTH{1'b0}}};
            2'b11 : mat_reg_in <= {mat_din, mat_reg[B_WIDTH+B_WIDTH-2:B_WIDTH]};
        endcase
    end
    
    always @(posedge clk) begin
        if(~mat_reg_resetn) begin
            mat_reg <= 'b0;
        end
        else begin
            mat_reg <= mat_reg_in;
        end
    end;
    
    // shift current input to left
    assign shift_sel = shift_sel_reg;
    assign mult_with_one_in = (cnt_mat_out == 2) ? {{(B_WIDTH-1){1'b0}}, 1'b1, {B_WIDTH{1'b0}}} : 'b0;
    assign mat_shifted_hi[0] = (mult_with_one == 1'b1) ? mult_with_one_in : {mat_reg, 1'b0};
    generate
        for(genvar S=0; S < LOGBWIDTH; S=S+1) begin
            assign mat_shifted_hi[S+1] = (shift_sel[LOGBWIDTH-1-S] == 1'b1) ? {mat_shifted_hi[S][2*B_WIDTH-1-2**(LOGBWIDTH-1-S):0], {(2**(LOGBWIDTH-1-S)){1'b0}}} : mat_shifted_hi[S];
        end
    endgenerate
        
    always @ (posedge clk) begin
        if(~shift_sel_resetn) begin
            shift_sel_reg <= 'b0;
            mult_with_one <= 1'b0;
        end
        else begin
            if(sample_res_addr) begin
                shift_sel_reg <= vec_din[LOGBWIDTH-1:0];
                mult_with_one <= vec_din[LOGRBITS];
            end
            else begin
                shift_sel_reg <= shift_sel_reg;
                mult_with_one <= mult_with_one;
            end
        end
    end
    /////////////////////////////////////////////////////////////////////////////
    
    
    
    // Counter //////////////////////////////////////////////////////////////////
    // Counts non-zero bits in sparse polynomial
    assign cnt_sparse_done = (cnt_sparse_out == hw_sparse-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(LOG_SIZE_HW), .MAX_VALUE(2**LOG_SIZE_HW-1))
    cnt_sparse (.clk(clk), .enable(cnt_sparse_enable), .resetn(cnt_sparse_resetn), .cnt_out(cnt_sparse_out));  
    
    // Determines the address for the matrix polynomial
    BIKE_mult_counter_inc_init #(.SIZE(LOGSWORDS), .INIT(SWORDS-2), .MAX_VALUE(SWORDS-1))
    cnt_matrix(.clk(clk), .enable(cnt_mat_enable), .resetn(cnt_mat_resetn), .cnt_out(cnt_mat_out)); 
    /////////////////////////////////////////////////////////////////////////////
    
    
    
    // FINITE STATE MACHINE (FSM) ///////////////////////////////////////////////
    localparam [3:0]
        s_idle                      =  0,
        s_init                      =  1,
        s_init0                     =  2,
        s_init1                     =  3,
        s_init2                     =  4,
        s_regular                   =  5,
        s_final                     =  6,
        s_final0                    =  7,
        s_done                      =  8;

        
    reg [3:0] state_reg, state_next;
    
    // state register
    always @ (posedge clk or negedge resetn) begin
        if(~resetn) begin
            state_reg <= s_idle;
        end
        else begin
            state_reg <= state_next;
        end
    end 
    
    // Next state logic
    always @(*) begin
        state_next <= state_reg;
        
        case(state_reg)
        
            // -----------------------------------
            s_idle : begin
                if(enable) begin    
                    state_next      <= s_init;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_init : begin 
                state_next          <= s_init0;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_init0 : begin 
                state_next          <= s_init1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_init1 : begin 
                state_next          <= s_init2;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_init2 : begin 
                state_next          <= s_regular;
            end
            // -----------------------------------

            // -----------------------------------
            s_regular : begin 
                if(cnt_mat_out == SWORDS-1) begin
                    state_next      <= s_final;
                end
                else begin
                    state_next      <= s_regular;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_final : begin 
                state_next          <= s_final0;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_final0 : begin 
                if(cnt_sparse_done) begin
                    state_next      <= s_done;
                end
                else begin
                    state_next      <= s_init;
                end
            end
            // -----------------------------------
                                                                                                                                                                                                                                                                                   
            // -----------------------------------
            s_done : begin
                if(~resetn) begin   
                    state_next      <= s_idle;
                end 
                else begin 
                    state_next      <= s_done;
                end
            end
            // -----------------------------------                                  
         endcase     
    end
    
    // output logic
    always @(state_reg) begin
        // default outputs
        // Global control
        done                        <= 1'b0;
        
        // counter
        cnt_sparse_resetn           <= 1'b0;
        cnt_sparse_enable           <= 1'b0;

        cnt_mat_resetn              <= 1'b0;
        cnt_mat_enable              <= 1'b0;
                
        // Memory interface
        vec_rden                    <= 1'b0;
        
        mat_rden                    <= 1'b0;
        
        resa_rden                   <= 1'b0;
        resb_rden                   <= 1'b0;
        res_wren                    <= 1'b0;
        
        res_addr_cnt_resetn         <= 1'b0;
        sample_res_addr             <= 1'b0;
        
        mat_reg_resetn              <= 1'b0;
        mat_reg_in_sel              <= 2'b00;
        
        wrapper_resetn              <= 1'b0;
        wrapper_fsm_enable          <= 1'b0;
        
        shift_sel_resetn            <= 1'b0;
        
        
        case (state_reg)
            // -----------------------------------
            s_idle : begin

            end
            // -----------------------------------

            // -----------------------------------
            s_init : begin                
                cnt_mat_resetn      <= 1'b1;
                cnt_mat_enable      <= 1'b1;
                
                cnt_sparse_resetn   <= 1'b1;  
                
                // vector
                vec_rden            <= 1'b1;
                
                // matrix
                mat_rden            <= 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_init0 : begin                
                cnt_mat_resetn      <= 1'b1;
                cnt_mat_enable      <= 1'b1;
                
                cnt_sparse_resetn   <= 1'b1;  
                
                // vector
                vec_rden            <= 1'b1;
                
                // matrix
                mat_rden            <= 1'b1;
                
                mat_reg_resetn      <= 1'b1;
                mat_reg_in_sel      <= 2'b01;
            end
            // -----------------------------------

            // -----------------------------------
            s_init1 : begin
                cnt_mat_resetn      <= 1'b1;
                cnt_mat_enable      <= 1'b1;
  
                cnt_sparse_resetn   <= 1'b1;  
                
                // matrix 
                mat_rden            <= 1'b1;

                mat_reg_resetn      <= 1'b1;
                mat_reg_in_sel      <= 2'b10;
                
                shift_sel_resetn    <= 1'b1;
                
                // result
                sample_res_addr     <= 1'b1;
                res_addr_cnt_resetn <= 1'b1;                                    
            end
            // -----------------------------------

            // -----------------------------------
            s_init2 : begin
                cnt_mat_resetn      <= 1'b1;
                cnt_mat_enable      <= 1'b1;
                                
                cnt_sparse_resetn   <= 1'b1;
                
                // matrix
                mat_rden            <= 1'b1;

                mat_reg_resetn      <= 1'b1;
                mat_reg_in_sel      <= 2'b11;
                
                shift_sel_resetn    <= 1'b1;
                
                // results
                res_addr_cnt_resetn <= 1'b1;
                resa_rden           <= 1'b1;
                resb_rden           <= 1'b1;    

            end
            // -----------------------------------

            // -----------------------------------
            s_regular : begin
                cnt_mat_resetn      <= 1'b1;
                cnt_mat_enable      <= 1'b1;
                                
                cnt_sparse_resetn   <= 1'b1;
                
                // matrix
                mat_rden            <= 1'b1;

                mat_reg_resetn      <= 1'b1;
                mat_reg_in_sel      <= 2'b11;
                
                shift_sel_resetn    <= 1'b1;
                
                // result
                res_addr_cnt_resetn <= 1'b1;
                 
                res_wren            <= 1'b1;
                resa_rden           <= 1'b1;
                resb_rden           <= 1'b1;
                
                wrapper_resetn      <= 1'b1;
                wrapper_fsm_enable  <= 1'b1;
            end
            // -----------------------------------        

            // -----------------------------------
            s_final : begin
                cnt_mat_resetn      <= 1'b1;
                cnt_mat_enable      <= 1'b1;
                                
                cnt_sparse_resetn   <= 1'b1;
                
                // matrix
                mat_rden            <= 1'b1;

                mat_reg_resetn      <= 1'b1;
                mat_reg_in_sel      <= 2'b11;
                
                shift_sel_resetn    <= 1'b1;
                
                // result
                res_addr_cnt_resetn <= 1'b1;
                 
                res_wren            <= 1'b1;
                resa_rden           <= 1'b1;
                resb_rden           <= 1'b1;
                
                wrapper_resetn      <= 1'b1;
                wrapper_fsm_enable  <= 1'b1;
            end
            // -----------------------------------  
            
            // -----------------------------------
            s_final0 : begin                                
                cnt_sparse_resetn   <= 1'b1;
                cnt_sparse_enable   <= 1'b1;              
                 
                res_wren            <= 1'b1;
                resa_rden           <= 1'b1;
                resb_rden           <= 1'b1;
                
                wrapper_resetn      <= 1'b1;
                wrapper_fsm_enable  <= 1'b1;  
                
                shift_sel_resetn    <= 1'b1;              
            end
            // -----------------------------------   
                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
            // -----------------------------------
            s_done : begin
                done                        <= 1'b1;
            end
            // -----------------------------------
        endcase
    end
    //////////////////////////////////////////////////////////////////////////////    
        

endmodule