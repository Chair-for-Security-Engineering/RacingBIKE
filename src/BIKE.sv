//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         21.09.2021 
// Module Name:         BIKE
// Description:         United BIKE design supporting KeyGen, Encaps, and Decaps.
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
    

module BIKE (
    input  clk,
    // Control Ports
    input  resetn,
    input  start,
    input  [2:0] instruction, // 001: KeyGen, 010: Encaps, 100: Decaps
    output reg busy,
    output reg done,
    // Randomness
    input  rand_valid,
    output rand_request,
    input  [31:0] rand_din,
    // Input Data
    output reg din_ready,                   // indicates that the BIKE module is ready to receive data
    input  [7:0] din_load,                  // used as valid and start signal - 00000001: Public Key, 00000010: Private Key h0, 00000100: Private Key h1, 00001000: Private Key sigma, 00010000: cryptogram c0, 00100000: cryptrogram c1, 01000000: Private Key h0 compact, 10000000: Private Key h1 compact
    input  din_done,                        // transmission completed
    input  [LOGDWORDS-1:0] din_addr,        // target address for input data
    input  [31:0] din,                      // input data divided into 32-bit chunks
    // Output Data
    input  wire [6:0] request_data,         // Request data: 0000 0001: h_0, 0000 0010: h_1, 0000 0100: sigma, 0000 1000: h, 0001 0000: c_0, 0010 0000: c_1, 0100 0000: k
    input  wire request_done,               // Used to indicate that all necessary data was read - initiates memory reset
    output reg dout_valid,
    output reg [LOGDWORDS-1:0] dout_addr,   // address of output data 
    output reg [31:0] dout                  // output data is transferred in 32-bit chunks
    );
    
    
    // Parameters ////////////////////////////////////////////////////////////////
    parameter SIZE_REG = 4;
    parameter SIZE_DP = 9;
    parameter W_DIV_2 = W/2;
    
     initial begin
        $display("W/2 LSB: %d", W_DIV_2[0]);
    end
    
    
    // Signals and wires /////////////////////////////////////////////////////////
    // Control signals
    reg  data_load_en;
    wire [6:0] din_load_gated;
    
    
    // Register banks
    wire reg_resetn [SIZE_REG-1:0];
    wire [7:0] reg_enable [SIZE_REG-1:0];
    wire [31:0] reg_din [SIZE_REG-1:0];
    wire [32*8-1:0] reg_dout [SIZE_REG-1:0];
    
    wire [7:0] m_reg_en;
    wire [31:0] m_reg_dout [0:7];
    wire [31:0] mprime_reg_dout [0:7];
    wire [31:0] c1_reg_dout [0:7];
    wire [31:0] k_reg_dout [0:7];
    wire [7:0] c1_reg_en;
    wire [7:0] k_reg_en;
    wire [7:0] mprime_reg_en;
    wire [7:0] seed_reg_en;
    
    wire [7:0] sigma_load_reg_en;
    wire [7:0] c1_load_reg_en;
    
    
    // Dual Port BRAMs
    reg  [4:0] dp_selection [SIZE_DP-1:0];
    reg  [4:0] dp_selection_fsm [SIZE_DP-1:0];
    reg  [4:0] dp_selection_load [SIZE_DP-1:0];
    
    reg  dp_sampling[SIZE_DP-1:0];
    reg  dp_ren0_samp [SIZE_DP-1:0], dp_ren1_samp [SIZE_DP-1:0];
    reg  dp_wen0_samp [SIZE_DP-1:0], dp_wen1_samp [SIZE_DP-1:0];
    reg  [LOGDWORDS-1:0] dp_addr0_samp [SIZE_DP-1:0];
    reg  [LOGDWORDS-1:0] dp_addr1_samp [SIZE_DP-1:0];
    reg  [31:0] dp_din0_samp [SIZE_DP-1:0];
    reg  [31:0] dp_din1_samp [SIZE_DP-1:0];
    wire [31:0] dp_dout0_samp [SIZE_DP-1:0];
    wire [31:0] dp_dout1_samp [SIZE_DP-1:0];
    
    reg  dp_wen0 [SIZE_DP-1:0], dp_wen1 [SIZE_DP-1:0];
    reg  dp_ren0 [SIZE_DP-1:0], dp_ren1 [SIZE_DP-1:0];
    reg  [LOGSWORDS-1:0] dp_addr0 [SIZE_DP-1:0];
    reg  [LOGSWORDS-1:0] dp_addr1 [SIZE_DP-1:0];
    reg  [B_WIDTH-1:0] dp_din0 [SIZE_DP-1:0];
    reg  [B_WIDTH-1:0] dp_din1 [SIZE_DP-1:0];
    wire [B_WIDTH-1:0] dp_dout0 [SIZE_DP-1:0];
    wire [B_WIDTH-1:0] dp_dout1 [SIZE_DP-1:0];
    
    
    // Multiplier
    wire [$clog2(T1)-1:0] mul_hw_sparse;
    reg  sel_hw_sparse;
    reg  [1:0] mul_sel;
    reg  mul_resetn, mul_enable;
    wire mul_first, mul_valid, mul_done;
    reg  mul_omit_init_add;
    wire mul_vec_rden;
    wire [LOGDWORDS-1:0] mul_vec_addr;
    reg  [31:0] mul_vec_din0;
    reg  [31:0] mul_vec_din1;

    reg  mul_init_add;
    wire mul_init_add_rden;
    wire [LOGSWORDS-1:0] mul_init_add_addr;
    wire [B_WIDTH-1:0] mul_init_add_din;
    reg  mul_recompute_syndrome_h1;

    wire [31:0] mul_recompute_syndrome_vec_din;
    wire [B_WIDTH-1:0] mul_recompute_syndrome_mat_din;

    wire syndrome_copy_rden;
    wire [B_WIDTH-1:0] syndrome_copy_din;
    wire [LOGSWORDS-1:0] syndrome_copy_addr;
    
    wire mul_mat_rden, mul_mat_wren;
    wire [LOGSWORDS-1:0] mul_mat_addr;
    wire [B_WIDTH-1:0] mul_mat_dout0;
    wire [B_WIDTH-1:0] mul_mat_dout1;
    wire [B_WIDTH-1:0] mul_mat_din0;
    wire [B_WIDTH-1:0] mul_mat_din1;
    wire mul_mata_rden, mul_mata_wren;
    wire [LOGSWORDS-1:0] mul_mata_addr;
    wire [B_WIDTH-1:0] mul_mata_dout0;
    wire [B_WIDTH-1:0] mul_mata_dout1;
    reg  [B_WIDTH-1:0] mul_mata_din0;
    reg  [B_WIDTH-1:0] mul_mata_din1;
    wire mul_matb_rden, mul_matb_wren;
    wire [LOGSWORDS-1:0] mul_matb_addr;
    wire [B_WIDTH-1:0] mul_matb_dout0;
    wire [B_WIDTH-1:0] mul_matb_dout1;
    reg  [B_WIDTH-1:0] mul_matb_din0;
    reg  [B_WIDTH-1:0] mul_matb_din1;
            
    wire mul_res_rden, mul_res_wren;
    wire [LOGSWORDS-1:0] mul_res_addr;
    wire [B_WIDTH-1:0] mul_res_dout;
    wire [B_WIDTH-1:0] mul_res_din;
    wire mul_resa_rden, mul_resa_wren;
    wire [LOGSWORDS-1:0] mul_resa_addr;
    wire [B_WIDTH-1:0] mul_resa_dout;
    reg  [B_WIDTH-1:0] mul_resa_din;
    wire mul_resb_rden, mul_resb_wren;
    wire [LOGSWORDS-1:0] mul_resb_addr;
    wire [B_WIDTH-1:0] mul_resb_dout;
    reg  [B_WIDTH-1:0] mul_resb_din;
    
    
    // Encode
    reg  enc_mul_enable;
    reg  enc_mul_resetn;
    wire enc_mul_done;
    wire enc_mul_result_rden;
    wire enc_mul_result_wren;
    wire [LOGSWORDS-1:0] enc_mul_result_addr;
    wire [B_WIDTH-1:0] enc_mul_result_din;
    wire [B_WIDTH-1:0] enc_mul_result_dout;
    wire enc_mul_matrix_rden;
    wire enc_mul_matrix_wren;
    wire [LOGSWORDS-1:0] enc_mul_matrix_addr;
    wire [B_WIDTH-1:0] enc_mul_matrix_din;
    wire [B_WIDTH-1:0] enc_mul_matrix_dout;
    wire enc_mul_vector_rden;
    wire [LOGSWORDS-1:0] enc_mul_vector_addr;
    wire [B_WIDTH-1:0] enc_mul_vector_din;
    
    
    // Secret Key
    wire sk_sample_done;
    reg  sk_sample_resetn;
    reg  sk_sample_enable;
    reg  sk0_sample_enable;
    reg  sk1_sample_enable;
    wire sk_sample_rand_requ;
    wire [int'($clog2(R_BITS))-1:0] sk_sample_rand;
    wire sk_sample_rden;
    wire sk_sample_wren;
    wire sk0_sample_rden;
    wire sk1_sample_rden;
    wire sk0_sample_wren;
    wire sk1_sample_wren;
    wire [LOGDWORDS-1:0] sk_sample_addr;
    wire [31:0] sk_sample_dout;
    wire [31:0] sk_sample_din;
    reg  sample_seed;
    
    wire h0_compact_sample_rden;
    wire h1_compact_sample_rden;
    wire h0_compact_sample_wren;
    wire h1_compact_sample_wren;
    wire [LOGDWORDS-1:0] h_compact_sample_addr;
    wire [31:0] h_compact_sample_dout;
    
    wire [255:0] sk_seed;
    wire sk_keccak_enable;
    wire sk_keccak_init;
    wire [STATE_WIDTH-1:0] sk_keccak_m;
    
    
    // Inversion
    reg  inv_enable; reg inv_resetn;
    wire inv_done;
    
    wire inv_sk0_rden;
    wire [LOGSWORDS-1:0] inv_sk0_addr;
    wire inv_sk1_rden;
    wire [LOGSWORDS-1:0] inv_sk1_addr;
    
    reg  inv_mul_enable;
    reg  inv_mul_resetn;
    reg  inv_mul_done;
    wire inv_mul_resulta_rden;
    wire inv_mul_resulta_wren;
    wire [LOGSWORDS-1:0] inv_mul_resulta_addr;
    wire [B_WIDTH-1:0] inv_mul_resulta_din;
    wire [B_WIDTH-1:0] inv_mul_resulta_dout;
    wire inv_mul_resultb_rden;
    wire inv_mul_resultb_wren;
    wire [LOGSWORDS-1:0] inv_mul_resultb_addr;
    wire [B_WIDTH-1:0] inv_mul_resultb_din;
    wire [B_WIDTH-1:0] inv_mul_resultb_dout;
    wire inv_mul_matrixa_rden;
    wire inv_mul_matrixa_wren;
    wire [LOGSWORDS-1:0] inv_mul_matrixa_addr;
    wire [B_WIDTH-1:0] inv_mul_matrixa_din;
    wire [B_WIDTH-1:0] inv_mul_matrixa_dout;
    wire inv_mul_matrixb_rden;
    wire inv_mul_matrixb_wren;
    wire [LOGSWORDS-1:0] inv_mul_matrixb_addr;
    wire [B_WIDTH-1:0] inv_mul_matrixb_din;
    wire [B_WIDTH-1:0] inv_mul_matrixb_dout;
    wire inv_mul_vector_rden;
    wire [LOGSWORDS-1:0] inv_mul_vector_addr;
    wire [B_WIDTH-1:0] inv_mul_vector_din;
    
    wire inv_bram_rden [7:0];
    wire inv_bram_wren [7:0];
    wire [LOGSWORDS-1:0] inv_bram_addr [7:0];
    wire [B_WIDTH-1:0] inv_bram_din [7:0];
    wire [B_WIDTH-1:0] inv_bram_dout [7:0];
    
    wire [1:0] inv_result_dst;
    reg  [1:0] inv_result_dst_d;
    
    
    // Message sampler
    reg  m_sample_resetn;
    reg  m_sample_enable;
    wire m_sample_done;
    wire m_sample_rand_requ;
    wire m_sample_wren;
    wire [$clog2(int'(L/32)):0] m_sample_addr;
    wire [31:0] m_sample_dout;
    
    
    // KECCAK
    reg  [1:0] hash_selection;
    reg  keccak_resetn;
    reg  keccak_enable;
    wire keccak_done;
    reg  keccak_init;
    reg  [STATE_WIDTH-1:0] keccak_m;
    wire [STATE_WIDTH-1:0] keccak_out;
    
    
    // H-Function (Error sampling)
    reg  sel_h;
    wire e_sample_done;
    reg  e_sample_resetn;
    reg  e_sample_enable;
    reg  e_sample_rden0; reg e_sample_rden1;
    reg  e_sample_wren0; reg e_sample_wren1;
    reg  [LOGDWORDS-1:0] e_sample_addr;
    reg  [31:0] e_sample_dout;
    wire [31:0] e_sample_din0; wire [31:0] e_sample_din1;

    wire e_sample_compact_rden;
    wire e_sample_compact_wren;
    wire [LOGDWORDS-1:0] e_sample_compact_addr;
    wire [31:0] e_sample_compact_dout;
    
    wire [255:0] h_seed;
    wire h_keccak_enable;
    wire h_keccak_init;
    wire [STATE_WIDTH-1:0] h_keccak_m;
    
    
    // L_Function
    reg  sel_l;
    wire l_keccak_enable;
    wire l_keccak_init;
    wire [STATE_WIDTH-1:0] l_keccak_m;
    
    reg  l_resetn; reg l_enable; 
    wire l_done; wire l_valid;
    wire [2:0] l_addr;
    wire [31:0] l_out;
    
    wire e_l_rden0; wire e_l_rden1;
    wire [LOGDWORDS-1:0] e_l_addr0; wire [LOGDWORDS-1:0] e_l_addr1;
    wire [31:0] e_l_din0; wire [31:0] e_l_din1;
    
    
    // K-Function
    reg  sel_k;
    wire k_keccak_enable;
    wire k_keccak_init;
    wire [STATE_WIDTH-1:0] k_keccak_m;

    reg  k_resetn; reg k_enable; 
    wire k_done; wire k_valid;
    wire [2:0] k_addr;
    wire [31:0] k_out;
    
    wire [255:0] m_k_din;
    wire [255:0] c1_k_din;
    wire c0_k_rden;
    wire [LOGDWORDS-1:0] c0_k_addr;
    wire [31:0] c0_k_din;
    
    wire [31:0] c0_k_din_encaps;
    wire [31:0] c0_k_din_decaps;
    
    
    // Copy memory (for inversion)
    reg  mem_copy_enable;
    reg  mem_copy_resetn;
    wire mem_copy_done;
    wire mem_copy_in_rden;
    wire [LOGSWORDS-1:0] mem_copy_in_addr;
    wire [B_WIDTH-1:0] mem_copy_in_din0;
    wire [B_WIDTH-1:0] mem_copy_in_din1;
    wire [B_WIDTH-1:0] mem_copy_in_din2;
    wire mem_copy_out_rden;
    wire mem_copy_out_wren;
    wire [LOGSWORDS-1:0] mem_copy_out_addr;
    wire [B_WIDTH-1:0] mem_copy_out_dout0;
    wire [B_WIDTH-1:0] mem_copy_out_dout1;
    wire [B_WIDTH-1:0] mem_copy_out_dout2;
    wire mem_copy_bram_wren [5:0];
    wire mem_copy_bram_rden [5:0];
    wire [LOGSWORDS-1:0] mem_copy_bram_addr [5:0];
    wire [B_WIDTH-1:0] mem_copy_bram_din [5:0];
    
    
    // Decaps multiplication
    reg  decaps_mul_resetn;
    reg  decaps_mul_enable;
    
    
    // Hamming Weight
    reg  cnt_hw_enable;
    reg  cnt_hw_resetn;
    wire cnt_hw_done;
    wire [LOGSWORDS-1:0] cnt_hw_out;
    
    reg  [1:0] hw_sel;
    reg  hw_enable;
    reg  hw_enable_d;
    reg  hw_resetn;
    reg  [B_WIDTH-1:0] hw_din;
    wire [B_WIDTH-1:0] hw_mul_din;
    wire [B_WIDTH-1:0] hw_bfiter_din;
    wire [LOGRBITS-1:0] hw_dout;
    
    reg  decoder_res_enable;
    reg  decoder_res_resetn;
    wire decoder_res_in;
    reg  decoder_res_out;
    
    reg  hw_check_e;
    wire hw_e_in;
    reg  hw_e_out;
    
    
    // Threshold
    wire cnt_hwth_done;
    reg  cnt_hwth_en;
    reg  cnt_hwth_rstn;
    wire [int'($clog2(LOGBWIDTH+2))-1:0] cnt_hwth_out;
    
    reg  th_enable;
    wire [LOGRBITS-1:0] th_din;
    wire [int'($clog2(W/2))-1:0] th_dout;
    
    
    // Syndrome
    reg  [1:0] syndrome_sel;
    reg  [B_WIDTH-1:0] syndrome_hw_din;
    wire [B_WIDTH-1:0] syndrome_a_upc_dout;
    
    
    // BFiter
    reg  cnt_nbiter_en;
    reg  cnt_nbiter_rstn;
    wire cnt_nbiter_done;
    wire [int'($clog2(NBITER+1))-1:0] cnt_nbiter_out;
    
    reg  bfiter_resetn;
    reg  bfiter_enable;
    reg  [1:0] bfiter_sel;
    wire bfiter_done;
    reg  [int'($clog2(W/2))-1:0] th_bfiter_in;
    
    wire syndrome_upc_rden;
    wire syndrome_upc_wren;
    wire [LOGSWORDS-1:0] syndrome_upc_a_addr;
    wire [B_WIDTH-1:0] syndrome_upc_a_din; 
    wire [B_WIDTH-1:0] syndrome_upc_a_dout; 
    wire [LOGSWORDS-1:0] syndrome_upc_b_addr;
    wire [B_WIDTH-1:0] syndrome_upc_b_din;
    wire [B_WIDTH-1:0] syndrome_upc_b_dout;
        
    wire sk0_bfiter_rden; wire sk1_bfiter_rden;
    wire sk0_bfiter_wren; wire sk1_bfiter_wren;
    wire [LOGDWORDS-1:0] sk_bfiter_addr;
    wire [31:0] sk_bfiter_dout;
    
    wire e0_bfiter_rden; wire e1_bfiter_rden;
    wire e0_bfiter_wren; wire e1_bfiter_wren;
    wire [LOGSWORDS-1:0] e_bfiter_addr;
    wire [B_WIDTH-1:0] e_bfiter_dout;

    wire black0_bfiter_rden; wire black1_bfiter_rden;
    wire black0_bfiter_wren; wire black1_bfiter_wren;
    wire [LOGSWORDS-1:0] black_bfiter_addr;
    wire [B_WIDTH-1:0] black_bfiter_dout;    
    
    wire gray0_bfiter_rden; wire gray1_bfiter_rden;
    wire gray0_bfiter_wren; wire gray1_bfiter_wren;
    wire [LOGSWORDS-1:0] gray_bfiter_addr;
    wire [B_WIDTH-1:0] gray_bfiter_dout;
    
    wire [B_WIDTH-1:0] recompute_syndrome_mul_resa_din;
    
    reg  cnt_copyh01_enable;
    reg  cnt_copyh01_resetn;
    wire [LOGSWORDS-1:0] cnt_copyh01_out;
    reg  [LOGSWORDS-1:0] copy_h01_dst_addr;
    
    wire copy_h01_wren [3:0];
    wire [LOGSWORDS-1:0] copy_h01_addr [3:0];
    wire [B_WIDTH-1:0] copy_h01_din [3:0];
    
    
    // compare error vectors
    wire cnt_compe_done;
    reg  cnt_compe_enable;
    reg  cnt_compe_resetn;
    wire [LOGSWORDS-1:0] cnt_compe_out;
    
    reg  sel_comp_error_poly;
    reg  e0_compe_rden;
    reg  e1_compe_rden;
    wire [B_WIDTH-1:0] compe_dina;
    wire [B_WIDTH-1:0] compe_dinb;
    wire [B_WIDTH-1:0] compe_xor; 
    
    reg  hw_compare_en;
    reg  hw_compare_rstn;
    reg  hw_compare_out;
    
    // copy error vector
    wire cnt_copy_done;
    reg  cnt_copy_enable;
    reg  cnt_copy_resetn;
    wire [LOGSWORDS-1:0] cnt_copy_out;
    wire e_copy_wren;
    

    // Output counter
    reg  cnt_out_resetn;
    reg  cnt_out_enable;
    reg  [LOGDWORDS-1:0] cnt_out_out;
    wire cnt_out_l_done;
    wire cnt_out_poly_done;
    
    reg  dout_valid_intern; 
    reg  dout_valid_intern_d;
    reg  sel_out; 
    reg  [LOGDWORDS-1:0] dout_addr_d;
    
    wire [31:0] c0_dout;
    reg  [31:0] h_dout;
    
    localparam[6:0]
        tx_h0       =  1,
        tx_h1       =  2,
        tx_sigma    =  4,
        tx_h        =  8,
        tx_c0       = 16,
        tx_c1       = 32,
        tx_k        = 64;
   
    
    // Description ///////////////////////////////////////////////////////////////
    
    
    // Register Banks ////////////////////////////////////////////////////////////
    generate for (genvar i=0; i < 8; i=i+1) begin
        assign m_reg_en[i]          = (m_sample_addr == i && (~sample_seed == 1'b1)) ? m_sample_wren : 1'b0; 
        assign sigma_load_reg_en[i] = (din_addr == i) ? 1'b1 : 1'b0;
        assign c1_reg_en[i]         = (l_addr == i && sel_l == 1'b0) ? l_valid : 1'b0; 
        assign c1_load_reg_en[i]    = (din_addr == i) ? 1'b1 : 1'b0;
        assign k_reg_en[i]          = k_addr == i ? k_valid : 1'b0;
        assign mprime_reg_en[i]     = (l_addr == i && sel_l == 1'b1) ? l_valid : 1'b0; 
        assign seed_reg_en[i]       = (m_sample_addr == i && (sample_seed == 1'b1)) ? m_sample_wren : 1'b0; 
    end endgenerate

    generate
        for(genvar i=0; i<8; i=i+1) begin
            assign m_reg_dout[i] = reg_dout[0][(i+1)*32-1:i*32];
            assign mprime_reg_dout[i] = reg_dout[3][(i+1)*32-1:i*32];
            assign c1_reg_dout[i] = reg_dout[1][(i+1)*32-1:i*32];
            assign k_reg_dout[i] = reg_dout[2][(i+1)*32-1:i*32];
        end
    endgenerate
    
    assign reg_enable[0] = (din_load == 8'b00001000) ? sigma_load_reg_en : m_reg_en;
    assign reg_resetn[0] = resetn;
    assign reg_din[0]    = (din_load == 8'b00001000) ? din : m_sample_dout;
    
    assign reg_enable[1] = (din_load == 8'b00100000) ? c1_load_reg_en : c1_reg_en;
    assign reg_resetn[1] = resetn;
    assign reg_din[1]    = (din_load == 8'b00100000) ? din : m_reg_dout[l_addr] ^ l_out;
    
    assign reg_enable[2] = (sample_seed) ? seed_reg_en : k_reg_en;
    assign reg_resetn[2] = resetn;
    assign reg_din[2]    = (sample_seed) ? m_sample_dout : k_out;
    
    assign reg_enable[3] = mprime_reg_en;
    assign reg_resetn[3] = resetn;
    assign reg_din[3]    = l_out ^ c1_reg_dout[l_addr];
    
    BIKE_register_banks #(.NUM_OF_BANKS(SIZE_REG), .BANK_SIZE(8)) reg_banks (
        .clk(clk),
        .resetn(reg_resetn),
        .enable(reg_enable),
        .din(reg_din),
        .dout(reg_dout)
    );
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Dual Port BRAM Bank ///////////////////////////////////////////////////////
    // 00111 - reset memory
    // Memory 0
    // Key Generation (001)
    // 00: Sample secret key
    // 01: Inversion
    // 11: Multiplication
    
    // Encaps (010)
    // 01: Error Sampler
    // 10: Multiplication
    
    // Decaps (100)
    // 00: H-Function
    // 11: Comparison
    
    assign dp_selection_load[0] = 5'b0;
    assign dp_selection[0] = (din_load != 'b0 || request_data != 'b0) ? dp_selection_load[0] : dp_selection_fsm[0];
    
    always @(*) begin
        case (dp_selection[0])
            5'b00001: begin
                dp_wen0_samp[0]     = sk0_sample_wren;
                dp_wen1_samp[0]     = sk1_sample_wren;
                dp_ren0_samp[0]     = sk0_sample_rden;
                dp_ren1_samp[0]     = sk1_sample_rden;
                dp_sampling[0]      = 1'b1;
                dp_addr0_samp[0]    = sk_sample_addr;
                dp_addr1_samp[0]    = sk_sample_addr;
                dp_din0_samp[0]     = sk_sample_dout;
                dp_din1_samp[0]     = sk_sample_dout;
                dp_wen0[0]          = 1'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = 1'b0;
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = 'b0;
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end

            5'b01001: begin
                dp_wen0_samp[0]     = 1'b0;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = 1'b0;
                dp_ren1_samp[0]     = 1'b0;
                dp_sampling[0]      = 1'b0;
                dp_addr0_samp[0]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[0]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[0]     = 32'b0;
                dp_din1_samp[0]     = 32'b0;
                dp_wen0[0]          = inv_bram_wren[0];
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = inv_bram_rden[0];
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = inv_bram_addr[0];
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = inv_bram_dout[0];
                dp_din1[0]          = 'b0;
            end

            5'b10001: begin
                dp_wen0_samp[0]     = 1'b0;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = 1'b1;
                dp_ren1_samp[0]     = 1'b1;
                dp_sampling[0]      = 1'b1;
                dp_addr0_samp[0]    = cnt_out_out;
                dp_addr1_samp[0]    = cnt_out_out;
                dp_din0_samp[0]     = 32'b0;
                dp_din1_samp[0]     = 32'b0;
                dp_wen0[0]          = 1'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = 1'b0;
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = 'b0;
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end
                                
            5'b01010 : begin
                dp_wen0_samp[0]     = e_sample_compact_wren;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = e_sample_compact_rden;
                dp_ren1_samp[0]     = 1'b0;
                dp_sampling[0]      = 1'b1;
                dp_addr0_samp[0]    = e_sample_compact_addr;
                dp_addr1_samp[0]    = 'b0;
                dp_din0_samp[0]     = e_sample_compact_dout;
                dp_din1_samp[0]     = 'b0;
                dp_wen0[0]          = 1'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = 1'b0;
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = 'b0;
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end

            5'b10010 : begin
                dp_wen0_samp[0]     = 1'b0;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = mul_vec_rden;
                dp_ren1_samp[0]     = 1'b0;
                dp_sampling[0]      = 1'b1;
                dp_addr0_samp[0]    = mul_vec_addr;
                dp_addr1_samp[0]    = 'b0;
                dp_din0_samp[0]     = 'b0;
                dp_din1_samp[0]     = 'b0;
                dp_wen0[0]          = 'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = 1'b0;
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = 'b0;
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end

            5'b00100: begin
                dp_wen0_samp[0]     = e_sample_wren0;
                dp_wen1_samp[0]     = e_sample_wren1;
                dp_ren0_samp[0]     = e_sample_rden0;
                dp_ren1_samp[0]     = e_sample_rden1;
                dp_sampling[0]      = e_sample_enable;
                dp_addr0_samp[0]    = e_sample_addr;
                dp_addr1_samp[0]    = e_sample_addr;
                dp_din0_samp[0]     = e_sample_dout;
                dp_din1_samp[0]     = e_sample_dout; 
                dp_wen0[0]          = 1'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = 1'b0;
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = 'b0;
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end                

            5'b11100 : begin
                dp_wen0_samp[0]     = 1'b0;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = 1'b0;
                dp_ren1_samp[0]     = 1'b0;
                dp_sampling[0]      = 1'b1;
                dp_addr0_samp[0]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[0]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[0]     = 32'b0;
                dp_din1_samp[0]     = 32'b0;
                dp_wen0[0]          = 1'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = e0_compe_rden;
                dp_ren1[0]          = e1_compe_rden;
                dp_addr0[0]         = cnt_compe_out;
                dp_addr1[0]         = cnt_compe_out;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end   
              
            5'b00111 : begin
                dp_wen0_samp[0]     = 1'b0;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = 1'b0;
                dp_ren1_samp[0]     = 1'b0;
                dp_sampling[0]      = 1'b0;
                dp_addr0_samp[0]    = 'b0;
                dp_addr1_samp[0]    = 'b0;
                dp_din0_samp[0]     = 'b0;
                dp_din1_samp[0]     = 'b0;
                dp_wen0[0]          = 1'b1;
                dp_wen1[0]          = 1'b1;
                dp_ren0[0]          = 1'b1;
                dp_ren1[0]          = 1'b1;
                dp_addr0[0]         = cnt_compe_out;
                dp_addr1[0]         = cnt_compe_out;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end              
                                                                       
            default : begin
                dp_wen0_samp[0]     = 1'b0;
                dp_wen1_samp[0]     = 1'b0;
                dp_ren0_samp[0]     = 1'b0;
                dp_ren1_samp[0]     = 1'b0;
                dp_sampling[0]      = 1'b0;
                dp_addr0_samp[0]    = 'b0;
                dp_addr1_samp[0]    = 'b0;
                dp_din0_samp[0]     = 'b0;
                dp_din1_samp[0]     = 'b0;
                dp_wen0[0]          = 1'b0;
                dp_wen1[0]          = 1'b0;
                dp_ren0[0]          = 1'b0;
                dp_ren1[0]          = 1'b0;
                dp_addr0[0]         = 'b0;
                dp_addr1[0]         = 'b0;
                dp_din0[0]          = 'b0;
                dp_din1[0]          = 'b0;
            end
        endcase
    end

    // Memory 1
    // KeyGen (001)
    // 01: Inversion
    // 10: Inversion Copy
    
    // Encaps (010)
    // 01: Multiplication
    // 10: K-Function
    
    // Decaps (100)
    // 00: Load private key h0 (compact)
    // 01: Load private key h1 (compact)
    // 10: Multiplication (vector h0)
    // 11: BFIter
    
    assign dp_selection_load[1] = (din_load == 8'b01000000) ? 5'b00100 : (din_load == 8'b10000000) ? 5'b01100 : (request_data == tx_c0 || request_data == tx_h) ? 5'b11111 : 5'b0;
    assign dp_selection[1] = (din_load != 'b0 || request_data != 'b0) ? dp_selection_load[1] : dp_selection_fsm[1];
    
    always @(*) begin
        case (dp_selection[1])
            5'b01001 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = 1'b0;
                dp_ren1_samp[1]     = 1'b0;
                dp_sampling[1]      = 1'b0;
                dp_addr0_samp[1]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[1]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[1]     = 32'b0;
                dp_din1_samp[1]     = 32'b0;
                dp_wen0[1]          = inv_bram_wren[1];
                dp_wen1[1]          = inv_bram_wren[2];
                dp_ren0[1]          = inv_bram_rden[1];
                dp_ren1[1]          = inv_bram_rden[2];
                dp_addr0[1]         = inv_bram_addr[1];
                dp_addr1[1]         = inv_bram_addr[2];
                dp_din0[1]          = inv_bram_dout[1];
                dp_din1[1]          = inv_bram_dout[2];
            end
                    
            5'b01010 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = 1'b0;
                dp_ren1_samp[1]     = 1'b0;
                dp_sampling[1]      = 1'b0;
                dp_addr0_samp[1]    = 'b0;
                dp_addr1_samp[1]    = 'b0;
                dp_din0_samp[1]     = 'b0;
                dp_din1_samp[1]     = 'b0;
                dp_wen0[1]          = mul_resa_wren;
                dp_wen1[1]          = mul_resb_wren;
                dp_ren0[1]          = mul_resa_rden;
                dp_ren1[1]          = mul_resb_rden;
                dp_addr0[1]         = mul_resa_addr;
                dp_addr1[1]         = mul_resb_addr;
                dp_din0[1]          = mul_resa_dout;
                dp_din1[1]          = mul_resb_dout;
            end

            5'b10010 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = c0_k_rden;
                dp_ren1_samp[1]     = c0_k_rden;
                dp_sampling[1]      = 1'b1;
                dp_addr0_samp[1]    = c0_k_addr;
                dp_addr1_samp[1]    = c0_k_addr;
                dp_din0_samp[1]     = 'b0;
                dp_din1_samp[1]     = 'b0;
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = {LOGSWORDS{1'b0}};
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = {B_WIDTH{1'b0}};
                dp_din1[1]          = 'b0;
            end
            
            5'b00100 : begin
                dp_wen0_samp[1]     = 1'b1;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = 1'b1;
                dp_ren1_samp[1]     = 1'b0;
                dp_sampling[1]      = 1'b1;
                dp_addr0_samp[1]    = din_addr;
                dp_addr1_samp[1]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[1]     = {din[15:0], din[15:0]};
                dp_din1_samp[1]     = 32'b0;
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = 'b0;
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end

            5'b01100 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b1;
                dp_ren0_samp[1]     = 1'b0;
                dp_ren1_samp[1]     = 1'b1;
                dp_sampling[1]      = 1'b1;
                dp_addr0_samp[1]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[1]    = din_addr;
                dp_din0_samp[1]     = 32'b0;
                dp_din1_samp[1]     = {din[15:0], din[15:0]};
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = 'b0;
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end    

            5'b10100 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = mul_vec_rden;
                dp_ren1_samp[1]     = mul_vec_rden;
                dp_sampling[1]      = 1'b1;
                dp_addr0_samp[1]    = mul_vec_addr;
                dp_addr1_samp[1]    = mul_vec_addr;
                dp_din0_samp[1]     = 32'b0;
                dp_din1_samp[1]     = 32'b0;
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = 'b0;
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end

            5'b11100 : begin
                dp_wen0_samp[1]     = sk0_bfiter_wren;
                dp_wen1_samp[1]     = sk1_bfiter_wren;
                dp_ren0_samp[1]     = sk0_bfiter_rden;
                dp_ren1_samp[1]     = sk1_bfiter_rden;
                dp_sampling[1]      = 1'b1;
                dp_addr0_samp[1]    = sk_bfiter_addr;
                dp_addr1_samp[1]    = sk_bfiter_addr;
                dp_din0_samp[1]     = sk_bfiter_dout;
                dp_din1_samp[1]     = sk_bfiter_dout;
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = 'b0;
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end

            5'b11111 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = 1'b1;
                dp_ren1_samp[1]     = 1'b1;
                dp_sampling[1]      = 1'b1;
                dp_addr0_samp[1]    = cnt_out_out;
                dp_addr1_samp[1]    = cnt_out_out;
                dp_din0_samp[1]     = 'b0;
                dp_din1_samp[1]     = 'b0;
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = 'b0;
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end

            5'b00111 : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = 1'b0;
                dp_ren1_samp[1]     = 1'b0;
                dp_sampling[1]      = 1'b0;
                dp_addr0_samp[1]    = 'b0;
                dp_addr1_samp[1]    = 'b0;
                dp_din0_samp[1]     = 'b0;
                dp_din1_samp[1]     = 'b0;
                dp_wen0[1]          = 1'b1;
                dp_wen1[1]          = 1'b1;
                dp_ren0[1]          = 1'b1;
                dp_ren1[1]          = 1'b1;
                dp_addr0[1]         = cnt_compe_out;
                dp_addr1[1]         = cnt_compe_out;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end   
                                                                                     
            default : begin
                dp_wen0_samp[1]     = 1'b0;
                dp_wen1_samp[1]     = 1'b0;
                dp_ren0_samp[1]     = 1'b0;
                dp_ren1_samp[1]     = 1'b0;
                dp_sampling[1]      = 1'b0;
                dp_addr0_samp[1]    = 'b0;
                dp_addr1_samp[1]    = 'b0;
                dp_din0_samp[1]     = 'b0;
                dp_din1_samp[1]     = 'b0;
                dp_wen0[1]          = 1'b0;
                dp_wen1[1]          = 1'b0;
                dp_ren0[1]          = 1'b0;
                dp_ren1[1]          = 1'b0;
                dp_addr0[1]         = 'b0;
                dp_addr1[1]         = 'b0;
                dp_din0[1]          = 'b0;
                dp_din1[1]          = 'b0;
            end
        endcase
    end   

    // Memory 2
    // KeyGen (001)
    // 01: Inversion
    // 10: Multiplication (result)
    
    // Encaps (010)
    // 00: Recieve public key
    // 01: Multiplication
    
    // Decaps (100)
    // 00: Load cryptogram c0
    // 01: Multiplication (matrix)
    // 10: K-Function

    assign dp_selection_load[2] = (din_load == 8'b00000001) ? 5'b00010 : (din_load == 8'b00010000) ? 5'b00100 : 5'b0;
    assign dp_selection[2] = (din_load != 7'b0 || request_data != 'b0) ? dp_selection_load[2] : dp_selection_fsm[2];
    
    always @(*) begin
        case (dp_selection[2])
            5'b01001 : begin
                dp_wen0_samp[2]     = 1'b0;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b0;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b0;
                dp_addr0_samp[2]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[2]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[2]     = 32'b0;
                dp_din1_samp[2]     = 32'b0;
                dp_wen0[2]          = inv_bram_wren[3];
                dp_wen1[2]          = inv_bram_wren[4];
                dp_ren0[2]          = inv_bram_rden[3];
                dp_ren1[2]          = inv_bram_rden[4];
                dp_addr0[2]         = inv_bram_addr[3];
                dp_addr1[2]         = inv_bram_addr[4];
                dp_din0[2]          = inv_bram_dout[3];
                dp_din1[2]          = inv_bram_dout[4];
            end
                    
            5'b00010 : begin
                dp_wen0_samp[2]     = 1'b1;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b1;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b1;
                dp_addr0_samp[2]    = din_addr;
                dp_addr1_samp[2]    = {DWORDS{1'b0}};
                dp_din0_samp[2]     = din;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b0;
                dp_wen1[2]          = 1'b0;
                dp_ren0[2]          = 1'b0;
                dp_ren1[2]          = 1'b0;
                dp_addr0[2]         = 'b0;
                dp_addr1[2]         = 'b0;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end
            
            5'b01010 : begin
                dp_wen0_samp[2]     = 1'b0;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b0;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b0;
                dp_addr0_samp[2]    = 'b0;
                dp_addr1_samp[2]    = 'b0;
                dp_din0_samp[2]     = 'b0;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b0;
                dp_wen1[2]          = 1'b0;
                dp_ren0[2]          = mul_mata_rden;
                dp_ren1[2]          = 1'b0;
                dp_addr0[2]         = mul_mata_addr;
                dp_addr1[2]         = 'b0;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end

            5'b00100 : begin
                dp_wen0_samp[2]     = 1'b1;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b1;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b1;
                dp_addr0_samp[2]    = din_addr;
                dp_addr1_samp[2]    = {DWORDS{1'b0}};
                dp_din0_samp[2]     = din;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b0;
                dp_wen1[2]          = 1'b0;
                dp_ren0[2]          = 1'b0;
                dp_ren1[2]          = 1'b0;
                dp_addr0[2]         = 'b0;
                dp_addr1[2]         = 'b0;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end      

            5'b01100 : begin
                dp_wen0_samp[2]     = 1'b0;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b0;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b0;
                dp_addr0_samp[2]    = 'b0;
                dp_addr1_samp[2]    = 'b0;
                dp_din0_samp[2]     = 'b0;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b0;
                dp_wen1[2]          = 1'b0;
                dp_ren0[2]          = mul_mata_rden;
                dp_ren1[2]          = 1'b0;
                dp_addr0[2]         = mul_mata_addr;
                dp_addr1[2]         = 'b0;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end  

            5'b10100 : begin
                dp_wen0_samp[2]     = 1'b0;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = c0_k_rden;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b1;
                dp_addr0_samp[2]    = c0_k_addr;
                dp_addr1_samp[2]    = 'b0;
                dp_din0_samp[2]     = 'b0;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b0;
                dp_wen1[2]          = 1'b0;
                dp_ren0[2]          = 1'b0;
                dp_ren1[2]          = 1'b0;
                dp_addr0[2]         = 'b0;
                dp_addr1[2]         = 'b0;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end 

            5'b00111 : begin
                dp_wen0_samp[2]     = 1'b0;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b0;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b0;
                dp_addr0_samp[2]    = 'b0;
                dp_addr1_samp[2]    = 'b0;
                dp_din0_samp[2]     = 'b0;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b1;
                dp_wen1[2]          = 1'b1;
                dp_ren0[2]          = 1'b1;
                dp_ren1[2]          = 1'b1;
                dp_addr0[2]         = cnt_compe_out;
                dp_addr1[2]         = cnt_compe_out;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end   
                                                                          
            default : begin
                dp_wen0_samp[2]     = 1'b0;
                dp_wen1_samp[2]     = 1'b0;
                dp_ren0_samp[2]     = 1'b0;
                dp_ren1_samp[2]     = 1'b0;
                dp_sampling[2]      = 1'b0;
                dp_addr0_samp[2]    = 'b0;
                dp_addr1_samp[2]    = 'b0;
                dp_din0_samp[2]     = 'b0;
                dp_din1_samp[2]     = 'b0;
                dp_wen0[2]          = 1'b0;
                dp_wen1[2]          = 1'b0;
                dp_ren0[2]          = 1'b0;
                dp_ren1[2]          = 1'b0;
                dp_addr0[2]         = 'b0;
                dp_addr1[2]         = 'b0;
                dp_din0[2]          = 'b0;
                dp_din1[2]          = 'b0;
            end
        endcase
    end    


    // Memory 3
    // KeyGen (001)
    // 01: Inversion
    // 10: Multiplication (matrix)
    
    // Encaps (010)
    // 01: Store a copy of the sampled error vector
    // 10: Hash the error vector (L-Function)
    
    // Decaps (100)
    // 00: Multiplication (result - initial syndrome)
    // 01: 
    
    assign dp_selection_load[3] = (request_data == tx_h) ? 5'b11111 : 5'b0;
    assign dp_selection[3] = (din_load != 'b0 || request_data != 'b0) ? dp_selection_load[3] : dp_selection_fsm[3];
    
    always @(*) begin
        case (dp_selection[3])
            5'b01001 : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = 1'b0;
                dp_ren1_samp[3]     = 1'b0;
                dp_sampling[3]      = 1'b0;
                dp_addr0_samp[3]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[3]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[3]     = {32'b0};
                dp_din1_samp[3]     = {32'b0};
                dp_wen0[3]          = inv_bram_wren[5];
                dp_wen1[3]          = inv_bram_wren[6];
                dp_ren0[3]          = inv_bram_rden[5];
                dp_ren1[3]          = inv_bram_rden[6];
                dp_addr0[3]         = inv_bram_addr[5];
                dp_addr1[3]         = inv_bram_addr[6];
                dp_din0[3]          = inv_bram_dout[5];
                dp_din1[3]          = inv_bram_dout[6];
            end

            5'b10001 : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = 1'b0;
                dp_ren1_samp[3]     = 1'b0;
                dp_sampling[3]      = 1'b0;
                dp_addr0_samp[3]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[3]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[3]     = 32'b0;
                dp_din1_samp[3]     = 32'b0;
                dp_wen0[3]          = 1'b0;
                dp_wen1[3]          = 1'b0;
                dp_ren0[3]          = mul_mata_rden;
                dp_ren1[3]          = 1'b0;
                dp_addr0[3]         = mul_mata_addr;
                dp_addr1[3]         = 'b0;
                dp_din0[3]          = 'b0;
                dp_din1[3]          = 'b0;
            end
                    
            5'b01010 : begin
                dp_wen0_samp[3]     = e_sample_wren0;
                dp_wen1_samp[3]     = e_sample_wren1;
                dp_ren0_samp[3]     = e_sample_rden0;
                dp_ren1_samp[3]     = e_sample_rden1;
                dp_sampling[3]      = 1'b1;
                dp_addr0_samp[3]    = e_sample_addr;
                dp_addr1_samp[3]    = e_sample_addr;
                dp_din0_samp[3]     = e_sample_dout;
                dp_din1_samp[3]     = e_sample_dout;
                dp_wen0[3]          = 1'b0;
                dp_wen1[3]          = 1'b0;
                dp_ren0[3]          = 1'b0;
                dp_ren1[3]          = 1'b0;
                dp_addr0[3]         = 'b0;
                dp_addr1[3]         = 'b0;
                dp_din0[3]          = 'b0;
                dp_din1[3]          = 'b0;
            end

            5'b10010 : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = e_l_rden0;
                dp_ren1_samp[3]     = e_l_rden1;
                dp_sampling[3]      = 1'b1;
                dp_addr0_samp[3]    = e_l_addr0;
                dp_addr1_samp[3]    = e_l_addr1;
                dp_din0_samp[3]     = 'b0;
                dp_din1_samp[3]     = 'b0;
                dp_wen0[3]          = 1'b0;
                dp_wen1[3]          = 1'b0;
                dp_ren0[3]          = 1'b0;
                dp_ren1[3]          = 1'b0;
                dp_addr0[3]         = 'b0;
                dp_addr1[3]         = 'b0;
                dp_din0[3]          = 'b0;
                dp_din1[3]          = 'b0;
            end

            5'b00100 : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = 1'b0;
                dp_ren1_samp[3]     = 1'b0;
                dp_sampling[3]      = 1'b0;
                dp_addr0_samp[3]    = 'b0;
                dp_addr1_samp[3]    = 'b0;
                dp_din0_samp[3]     = 32'b0;
                dp_din1_samp[3]     = 32'b0;
                dp_wen0[3]          = mul_resa_wren;
                dp_wen1[3]          = mul_resb_wren;
                dp_ren0[3]          = mul_resa_rden;
                dp_ren1[3]          = mul_resb_rden;
                dp_addr0[3]         = mul_resa_addr;
                dp_addr1[3]         = mul_resb_addr;
                dp_din0[3]          = mul_resa_dout;
                dp_din1[3]          = mul_resb_dout;
            end 

            5'b11111 : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = 1'b1;
                dp_ren1_samp[3]     = 1'b0;
                dp_sampling[3]      = 1'b1;
                dp_addr0_samp[3]    = cnt_out_out;
                dp_addr1_samp[3]    = 'b0;
                dp_din0_samp[3]     = 'b0;
                dp_din1_samp[3]     = 'b0;
                dp_wen0[3]          = 1'b0;
                dp_wen1[3]          = 1'b0;
                dp_ren0[3]          = 1'b0;
                dp_ren1[3]          = 1'b0;
                dp_addr0[3]         = 'b0;
                dp_addr1[3]         = 'b0;
                dp_din0[3]          = 'b0;
                dp_din1[3]          = 'b0;
            end

            5'b00111 : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = 1'b0;
                dp_ren1_samp[3]     = 1'b0;
                dp_sampling[3]      = 1'b0;
                dp_addr0_samp[3]    = 'b0;
                dp_addr1_samp[3]    = 'b0;
                dp_din0_samp[3]     = 'b0;
                dp_din1_samp[3]     = 'b0;
                dp_wen0[3]          = 1'b1;
                dp_wen1[3]          = 1'b1;
                dp_ren0[3]          = 1'b1;
                dp_ren1[3]          = 1'b1;
                dp_addr0[3]         = cnt_compe_out;
                dp_addr1[3]         = cnt_compe_out;
                dp_din0[3]          = 'b0;
                dp_din1[3]          = 'b0;
            end   
                                                                                           
            default : begin
                dp_wen0_samp[3]     = 1'b0;
                dp_wen1_samp[3]     = 1'b0;
                dp_ren0_samp[3]     = 1'b0;
                dp_ren1_samp[3]     = 1'b0;
                dp_sampling[3]      = 1'b0;
                dp_addr0_samp[3]    = 'b0;
                dp_addr1_samp[3]    = 'b0;
                dp_din0_samp[3]     = 'b0;
                dp_din1_samp[3]     = 'b0;
                dp_wen0[3]          = 1'b0;
                dp_wen1[3]          = 1'b0;
                dp_ren0[3]          = 1'b0;
                dp_ren1[3]          = 1'b0;
                dp_addr0[3]         = 'b0;
                dp_addr1[3]         = 'b0;
                dp_din0[3]          = 'b0;
                dp_din1[3]          = 'b0;
            end
        endcase
    end    


    // Memory 4
    // Key Gen (001)    
    // 01: Inversion 
    // 10: Multiplication (matrix)
    // 11: Sample compact representation h1

    // Decaps (100)
    // 00: Store syndrome copy (working copy)
    // 01: BFIter
    
    assign dp_selection_load[4] = 'b0;
    assign dp_selection[4] = din_load != 'b0 ? dp_selection_load[4] : dp_selection_fsm[4];
    
    always @(*) begin
        case (dp_selection[4]) 
            5'b01001 : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = inv_bram_wren[7];
                dp_wen1[4]          = 1'b0;
                dp_ren0[4]          = inv_bram_rden[7];
                dp_ren1[4]          = 1'b0;
                dp_addr0[4]         = inv_bram_addr[7];
                dp_addr1[4]         = 'b0;
                dp_din0[4]          = inv_bram_dout[7];
                dp_din1[4]          = 'b0;
            end

            5'b10001 : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = 1'b0;
                dp_wen1[4]          = 1'b0;
                dp_ren0[4]          = mul_mata_rden;
                dp_ren1[4]          = 1'b0;
                dp_addr0[4]         = mul_mata_addr;
                dp_addr1[4]         = 'b0;
                dp_din0[4]          = 'b0;
                dp_din1[4]          = 'b0;
            end
            
            5'b11001 : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = 'b0;
                dp_wen1[4]          = h1_compact_sample_wren;
                dp_ren0[4]          = 'b0;
                dp_ren1[4]          = h1_compact_sample_rden;
                dp_addr0[4]         = 'b0;
                dp_addr1[4]         = h_compact_sample_addr;
                dp_din0[4]          = 'b0;
                dp_din1[4]          = h_compact_sample_dout;
            end

            5'b00100 : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = mul_valid;
                dp_wen1[4]          = mul_valid;
                dp_ren0[4]          = syndrome_copy_rden;
                dp_ren1[4]          = syndrome_copy_rden;
                dp_addr0[4]         = syndrome_copy_addr;
                dp_addr1[4]         = syndrome_copy_addr;
                dp_din0[4]          = syndrome_copy_din;
                dp_din1[4]          = syndrome_copy_din;
            end

            5'b01100 : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = syndrome_upc_wren;
                dp_wen1[4]          = syndrome_upc_wren;
                dp_ren0[4]          = syndrome_upc_rden;
                dp_ren1[4]          = syndrome_upc_rden;
                dp_addr0[4]         = syndrome_upc_a_addr;
                dp_addr1[4]         = syndrome_upc_b_addr;
                dp_din0[4]          = syndrome_upc_a_dout;
                dp_din1[4]          = syndrome_upc_b_dout;
            end 

            5'b00111 : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = 1'b1;
                dp_wen1[4]          = 1'b1;
                dp_ren0[4]          = 1'b1;
                dp_ren1[4]          = 1'b1;
                dp_addr0[4]         = cnt_compe_out;
                dp_addr1[4]         = cnt_compe_out;
                dp_din0[4]          = 'b0;
                dp_din1[4]          = 'b0;
            end 

            default : begin
                dp_wen0_samp[4]     = 1'b0;
                dp_wen1_samp[4]     = 1'b0;
                dp_ren0_samp[4]     = 1'b0;
                dp_ren1_samp[4]     = 1'b0;
                dp_sampling[4]      = 1'b0;
                dp_addr0_samp[4]    = 'b0;
                dp_addr1_samp[4]    = 'b0;
                dp_din0_samp[4]     = 'b0;
                dp_din1_samp[4]     = 'b0;
                dp_wen0[4]          = 1'b0;
                dp_wen1[4]          = 1'b0;
                dp_ren0[4]          = 1'b0;
                dp_ren1[4]          = 1'b0;
                dp_addr0[4]         = 'b0;
                dp_addr1[4]         = 'b0;
                dp_din0[4]          = 'b0;
                dp_din1[4]          = 'b0;
            end
        endcase
    end    
    
    
    // Memory 5
    // KeyGen (001)
    // 01: Multiplication (result)

    // Decaps (100)
    // 00: BFIter (error)
    // 01: Recompute syndrome
    // 10: L-Function
    // 11: Comparison
    
    assign dp_selection_load[5] = (request_data == tx_h) ? 5'b11111 : 'b0;
    assign dp_selection[5] = (din_load != 'b0 || request_data != 'b0) ? dp_selection_load[5] : dp_selection_fsm[5];

    always @(*) begin
        case (dp_selection[5])    
            5'b01001 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b0;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b0;
                dp_addr0_samp[5]    = {LOGDWORDS{1'b0}};
                dp_addr1_samp[5]    = {LOGDWORDS{1'b0}};
                dp_din0_samp[5]     = 32'b0;
                dp_din1_samp[5]     = 32'b0;
                dp_wen0[5]          = mul_resa_wren;
                dp_wen1[5]          = mul_resb_wren;
                dp_ren0[5]          = mul_resa_rden;
                dp_ren1[5]          = mul_resb_rden;
                dp_addr0[5]         = mul_resa_addr;
                dp_addr1[5]         = mul_resb_addr;
                dp_din0[5]          = mul_resa_dout;
                dp_din1[5]          = mul_resb_dout;
            end

            5'b00100 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b0;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b0;
                dp_addr0_samp[5]    = 'b0;
                dp_addr1_samp[5]    = 'b0;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = e0_bfiter_wren;
                dp_wen1[5]          = e1_bfiter_wren;
                dp_ren0[5]          = e0_bfiter_rden;
                dp_ren1[5]          = e1_bfiter_rden;
                dp_addr0[5]         = e_bfiter_addr;
                dp_addr1[5]         = e_bfiter_addr;
                dp_din0[5]          = e_bfiter_dout;
                dp_din1[5]          = e_bfiter_dout;
            end

            5'b01100 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b0;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b0;
                dp_addr0_samp[5]    = 'b0;
                dp_addr1_samp[5]    = 'b0;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = 1'b0;
                dp_wen1[5]          = 1'b0;
                dp_ren0[5]          = mul_mata_rden;
                dp_ren1[5]          = mul_mata_rden;
                dp_addr0[5]         = mul_mata_addr;
                dp_addr1[5]         = mul_mata_addr;
                dp_din0[5]          = 'b0;
                dp_din1[5]          = 'b0;
            end

            5'b10100 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = e_l_rden0;
                dp_ren1_samp[5]     = e_l_rden1;
                dp_sampling[5]      = 1'b1;
                dp_addr0_samp[5]    = e_l_addr0;
                dp_addr1_samp[5]    = e_l_addr1;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = 1'b0;
                dp_wen1[5]          = 1'b0;
                dp_ren0[5]          = 1'b0;
                dp_ren1[5]          = 1'b0;
                dp_addr0[5]         = 'b0;
                dp_addr1[5]         = 'b0;
                dp_din0[5]          = 'b0;
                dp_din1[5]          = 'b0;
            end

            5'b11100 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b0;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b1;
                dp_addr0_samp[5]    = 'b0;
                dp_addr1_samp[5]    = 'b0;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = 1'b0;
                dp_wen1[5]          = 1'b0;
                dp_ren0[5]          = e0_compe_rden;
                dp_ren1[5]          = e1_compe_rden;
                dp_addr0[5]         = cnt_compe_out;
                dp_addr1[5]         = cnt_compe_out;
                dp_din0[5]          = 'b0;
                dp_din1[5]          = 'b0;
            end

            5'b00111 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b0;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b0;
                dp_addr0_samp[5]    = 'b0;
                dp_addr1_samp[5]    = 'b0;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = 1'b1;
                dp_wen1[5]          = 1'b1;
                dp_ren0[5]          = 1'b1;
                dp_ren1[5]          = 1'b1;
                dp_addr0[5]         = cnt_compe_out;
                dp_addr1[5]         = cnt_compe_out;
                dp_din0[5]          = 'b0;
                dp_din1[5]          = 'b0;
            end  

            5'b11111 : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b1;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b1;
                dp_addr0_samp[5]    = cnt_out_out;
                dp_addr1_samp[5]    = 'b0;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = 1'b0;
                dp_wen1[5]          = 1'b0;
                dp_ren0[5]          = 1'b0;
                dp_ren1[5]          = 1'b0;
                dp_addr0[5]         = 'b0;
                dp_addr1[5]         = 'b0;
                dp_din0[5]          = 'b0;
                dp_din1[5]          = 'b0;
            end 
                       
            default : begin
                dp_wen0_samp[5]     = 1'b0;
                dp_wen1_samp[5]     = 1'b0;
                dp_ren0_samp[5]     = 1'b0;
                dp_ren1_samp[5]     = 1'b0;
                dp_sampling[5]      = 1'b0;
                dp_addr0_samp[5]    = 'b0;
                dp_addr1_samp[5]    = 'b0;
                dp_din0_samp[5]     = 'b0;
                dp_din1_samp[5]     = 'b0;
                dp_wen0[5]          = 1'b0;
                dp_wen1[5]          = 1'b0;
                dp_ren0[5]          = 1'b0;
                dp_ren1[5]          = 1'b0;
                dp_addr0[5]         = 'b0;
                dp_addr1[5]         = 'b0;
                dp_din0[5]          = 'b0;
                dp_din1[5]          = 'b0;
            end
        endcase
    end    


    // Memory 6
    // KeyGen (001)
    // 01: Sample h0 compact
    // 10

    // Decaps (100)
    // 00: BFIter (black)
    // 01: 

    assign dp_selection_load[6] = (request_data == tx_h0 || request_data == tx_h1) ? 5'b11111 : 'b0;
    assign dp_selection[6] = (din_load != 'b0 || request_data != 'b0) ? dp_selection_load[6] : dp_selection_fsm[6];

    always @(*) begin
        case (dp_selection[6])  
            5'b01001 : begin
                dp_wen0_samp[6]     = h0_compact_sample_wren;
                dp_wen1_samp[6]     = h1_compact_sample_wren;
                dp_ren0_samp[6]     = h0_compact_sample_rden;
                dp_ren1_samp[6]     = h1_compact_sample_rden;
                dp_sampling[6]      = 1'b1;
                dp_addr0_samp[6]    = h_compact_sample_addr;
                dp_addr1_samp[6]    = h_compact_sample_addr;
                dp_din0_samp[6]     = h_compact_sample_dout;
                dp_din1_samp[6]     = h_compact_sample_dout;
                dp_wen0[6]          = 1'b0;
                dp_wen1[6]          = 1'b0;
                dp_ren0[6]          = 1'b0;
                dp_ren1[6]          = 1'b0;
                dp_addr0[6]         = 'b0;
                dp_addr1[6]         = 'b0;
                dp_din0[6]          = 'b0;
                dp_din1[6]          = 'b0;
            end

            5'b10001 : begin
                dp_wen0_samp[6]     = 1'b0;
                dp_wen1_samp[6]     = 1'b0;
                dp_ren0_samp[6]     = 1'b0;
                dp_ren1_samp[6]     = mul_vec_rden;
                dp_sampling[6]      = 1'b1;
                dp_addr0_samp[6]    = 'b0;
                dp_addr1_samp[6]    = mul_vec_addr;
                dp_din0_samp[6]     = 'b0;
                dp_din1_samp[6]     = 'b0;
                dp_wen0[6]          = 1'b0;
                dp_wen1[6]          = 1'b0;
                dp_ren0[6]          = 1'b0;
                dp_ren1[6]          = 1'b0;
                dp_addr0[6]         = 'b0;
                dp_addr1[6]         = 'b0;
                dp_din0[6]          = 'b0;
                dp_din1[6]          = 'b0;
            end

            5'b00100 : begin
                dp_wen0_samp[6]     = 1'b0;
                dp_wen1_samp[6]     = 1'b0;
                dp_ren0_samp[6]     = 1'b0;
                dp_ren1_samp[6]     = 1'b0;
                dp_sampling[6]      = 1'b0;
                dp_addr0_samp[6]    = 'b0;
                dp_addr1_samp[6]    = 'b0;
                dp_din0_samp[6]     = 'b0;
                dp_din1_samp[6]     = 'b0;
                dp_wen0[6]          = black0_bfiter_wren;
                dp_wen1[6]          = black1_bfiter_wren;
                dp_ren0[6]          = black0_bfiter_rden;
                dp_ren1[6]          = black1_bfiter_rden;
                dp_addr0[6]         = black_bfiter_addr;
                dp_addr1[6]         = black_bfiter_addr;
                dp_din0[6]          = black_bfiter_dout;
                dp_din1[6]          = black_bfiter_dout;
            end

            5'b00111 : begin
                dp_wen0_samp[6]     = 1'b0;
                dp_wen1_samp[6]     = 1'b0;
                dp_ren0_samp[6]     = 1'b0;
                dp_ren1_samp[6]     = 1'b0;
                dp_sampling[6]      = 1'b0;
                dp_addr0_samp[6]    = 'b0;
                dp_addr1_samp[6]    = 'b0;
                dp_din0_samp[6]     = 'b0;
                dp_din1_samp[6]     = 'b0;
                dp_wen0[6]          = 1'b1;
                dp_wen1[6]          = 1'b1;
                dp_ren0[6]          = 1'b1;
                dp_ren1[6]          = 1'b1;
                dp_addr0[6]         = cnt_compe_out;
                dp_addr1[6]         = cnt_compe_out;
                dp_din0[6]          = 'b0;
                dp_din1[6]          = 'b0;
            end  

            5'b11111 : begin
                dp_wen0_samp[6]     = 1'b0;
                dp_wen1_samp[6]     = 1'b0;
                dp_ren0_samp[6]     = 1'b1;
                dp_ren1_samp[6]     = 1'b1;
                dp_sampling[6]      = 1'b1;
                dp_addr0_samp[6]    = cnt_out_out;
                dp_addr1_samp[6]    = cnt_out_out;
                dp_din0_samp[6]     = 'b0;
                dp_din1_samp[6]     = 'b0;
                dp_wen0[6]          = 1'b0;
                dp_wen1[6]          = 1'b0;
                dp_ren0[6]          = 1'b0;
                dp_ren1[6]          = 1'b0;
                dp_addr0[6]         = 'b0;
                dp_addr1[6]         = 'b0;
                dp_din0[6]          = 'b0;
                dp_din1[6]          = 'b0;
            end 
                        
            default : begin
                dp_wen0_samp[6]     = 1'b0;
                dp_wen1_samp[6]     = 1'b0;
                dp_ren0_samp[6]     = 1'b0;
                dp_ren1_samp[6]     = 1'b0;
                dp_sampling[6]      = 1'b0;
                dp_addr0_samp[6]    = 'b0;
                dp_addr1_samp[6]    = 'b0;
                dp_din0_samp[6]     = 'b0;
                dp_din1_samp[6]     = 'b0;
                dp_wen0[6]          = 1'b0;
                dp_wen1[6]          = 1'b0;
                dp_ren0[6]          = 1'b0;
                dp_ren1[6]          = 1'b0;
                dp_addr0[6]         = 'b0;
                dp_addr1[6]         = 'b0;
                dp_din0[6]          = 'b0;
                dp_din1[6]          = 'b0;
            end
        endcase
    end  
    
    // Memory 7
    // Decaps (100)
    // 00: BFIter (gray)
    // 01: 
    // 10: 
    
    assign dp_selection_load[7] = (din_load == 8'b01000000) ? 5'b00100 : (din_load == 8'b10000000) ? 5'b01100 : 5'b0;
    assign dp_selection[7] = din_load != 'b0 ? dp_selection_load[7] : dp_selection_fsm[7];

    always @(*) begin
        case (dp_selection[7])    
            5'b00100 : begin
                dp_wen0_samp[7]     = 1'b0;
                dp_wen1_samp[7]     = 1'b0;
                dp_ren0_samp[7]     = 1'b0;
                dp_ren1_samp[7]     = 1'b0;
                dp_sampling[7]      = 1'b0;
                dp_addr0_samp[7]    = 'b0;
                dp_addr1_samp[7]    = 'b0;
                dp_din0_samp[7]     = 32'b0;
                dp_din1_samp[7]     = 32'b0;
                dp_wen0[7]          = gray0_bfiter_wren;
                dp_wen1[7]          = gray1_bfiter_wren;
                dp_ren0[7]          = gray0_bfiter_rden;
                dp_ren1[7]          = gray1_bfiter_rden;
                dp_addr0[7]         = gray_bfiter_addr;
                dp_addr1[7]         = gray_bfiter_addr;
                dp_din0[7]          = gray_bfiter_dout;
                dp_din1[7]          = gray_bfiter_dout;
            end          

            5'b00111 : begin
                dp_wen0_samp[7]     = 1'b0;
                dp_wen1_samp[7]     = 1'b0;
                dp_ren0_samp[7]     = 1'b0;
                dp_ren1_samp[7]     = 1'b0;
                dp_sampling[7]      = 1'b0;
                dp_addr0_samp[7]    = 'b0;
                dp_addr1_samp[7]    = 'b0;
                dp_din0_samp[7]     = 'b0;
                dp_din1_samp[7]     = 'b0;
                dp_wen0[7]          = 1'b1;
                dp_wen1[7]          = 1'b1;
                dp_ren0[7]          = 1'b1;
                dp_ren1[7]          = 1'b1;
                dp_addr0[7]         = cnt_compe_out;
                dp_addr1[7]         = cnt_compe_out;
                dp_din0[7]          = 'b0;
                dp_din1[7]          = 'b0;
            end   
                        
            default : begin
                dp_wen0_samp[7]     = 1'b0;
                dp_wen1_samp[7]     = 1'b0;
                dp_ren0_samp[7]     = 1'b0;
                dp_ren1_samp[7]     = 1'b0;
                dp_sampling[7]      = 1'b0;
                dp_addr0_samp[7]    = 'b0;
                dp_addr1_samp[7]    = 'b0;
                dp_din0_samp[7]     = 'b0;
                dp_din1_samp[7]     = 'b0;
                dp_wen0[7]          = 1'b0;
                dp_wen1[7]          = 1'b0;
                dp_ren0[7]          = 1'b0;
                dp_ren1[7]          = 1'b0;
                dp_addr0[7]         = 'b0;
                dp_addr1[7]         = 'b0;
                dp_din0[7]          = 'b0;
                dp_din1[7]          = 'b0;
            end
        endcase
    end    

    // Memory 8
    // Decaps (100)
    // 00: Store copy of initial syndrome
    // 01: Recompute syndrome
    
    assign dp_selection_load[8] = 5'b0;
    assign dp_selection[8] = din_load != 'b0 ? dp_selection_load[8] : dp_selection_fsm[8];

    always @(*) begin
        case (dp_selection[8])          
            5'b00100 : begin
                dp_wen0_samp[8]     = 1'b0;
                dp_wen1_samp[8]     = 1'b0;
                dp_ren0_samp[8]     = 1'b0;
                dp_ren1_samp[8]     = 1'b0;
                dp_sampling[8]      = 1'b0;
                dp_addr0_samp[8]    = 'b0;
                dp_addr1_samp[8]    = 'b0;
                dp_din0_samp[8]     = 'b0;
                dp_din1_samp[8]     = 'b0;
                dp_wen0[8]          = mul_valid;
                dp_wen1[8]          = 1'b0;
                dp_ren0[8]          = mul_valid;
                dp_ren1[8]          = 1'b0;
                dp_addr0[8]         = syndrome_copy_addr;
                dp_addr1[8]         = 'b0;
                dp_din0[8]          = syndrome_copy_din;
                dp_din1[8]          = 'b0;
            end

            5'b01100 : begin
                dp_wen0_samp[8]     = 1'b0;
                dp_wen1_samp[8]     = 1'b0;
                dp_ren0_samp[8]     = 1'b0;
                dp_ren1_samp[8]     = 1'b0;
                dp_sampling[8]      = 1'b0;
                dp_addr0_samp[8]    = 'b0;
                dp_addr1_samp[8]    = 'b0;
                dp_din0_samp[8]     = 'b0;
                dp_din1_samp[8]     = 'b0;
                dp_wen0[8]          = 1'b0;
                dp_wen1[8]          = 1'b0;
                dp_ren0[8]          = mul_init_add_rden;
                dp_ren1[8]          = 1'b0;
                dp_addr0[8]         = mul_init_add_addr;
                dp_addr1[8]         = 'b0;
                dp_din0[8]          = 'b0;
                dp_din1[8]          = 'b0;
            end                 

            5'b00111 : begin
                dp_wen0_samp[8]     = 1'b0;
                dp_wen1_samp[8]     = 1'b0;
                dp_ren0_samp[8]     = 1'b0;
                dp_ren1_samp[8]     = 1'b0;
                dp_sampling[8]      = 1'b0;
                dp_addr0_samp[8]    = 'b0;
                dp_addr1_samp[8]    = 'b0;
                dp_din0_samp[8]     = 'b0;
                dp_din1_samp[8]     = 'b0;
                dp_wen0[8]          = 1'b1;
                dp_wen1[8]          = 1'b1;
                dp_ren0[8]          = 1'b1;
                dp_ren1[8]          = 1'b1;
                dp_addr0[8]         = cnt_compe_out;
                dp_addr1[8]         = cnt_compe_out;
                dp_din0[8]          = 'b0;
                dp_din1[8]          = 'b0;
            end   
                                      
            default : begin
                dp_wen0_samp[8]     = 1'b0;
                dp_wen1_samp[8]     = 1'b0;
                dp_ren0_samp[8]     = 1'b0;
                dp_ren1_samp[8]     = 1'b0;
                dp_sampling[8]      = 1'b0;
                dp_addr0_samp[8]    = 'b0;
                dp_addr1_samp[8]    = 'b0;
                dp_din0_samp[8]     = 'b0;
                dp_din1_samp[8]     = 'b0;
                dp_wen0[8]          = 1'b0;
                dp_wen1[8]          = 1'b0;
                dp_ren0[8]          = 1'b0;
                dp_ren1[8]          = 1'b0;
                dp_addr0[8]         = 'b0;
                dp_addr1[8]         = 'b0;
                dp_din0[8]          = 'b0;
                dp_din1[8]          = 'b0;
            end
        endcase
    end    
                              
    BIKE_BRAM_dp_bank #(.SIZE(SIZE_DP))
        DP_BRAMs (
            .clk(clk),
            .resetn(resetn),
            .sampling(dp_sampling),
            // Sampling 
            .ren0_samp(dp_ren0_samp),
            .ren1_samp(dp_ren1_samp),
            .wen0_samp(dp_wen0_samp),
            .wen1_samp(dp_wen1_samp),
            .addr0_samp(dp_addr0_samp),
            .addr1_samp(dp_addr1_samp),
            .din0_samp(dp_din0_samp),
            .din1_samp(dp_din1_samp),
            .dout0_samp(dp_dout0_samp),
            .dout1_samp(dp_dout1_samp),
            // Computation
            .wen0(dp_wen0),
            .wen1(dp_wen1),
            .ren0(dp_ren0),
            .ren1(dp_ren1),
            .addr0(dp_addr0),
            .addr1(dp_addr1),
            .din0(dp_din0),
            .din1(dp_din1),
            .dout0(dp_dout0),
            .dout1(dp_dout1)
        );
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Randomness ////////////////////////////////////////////////////////////////
    assign rand_request = m_sample_rand_requ;
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Sample secret key /////////////////////////////////////////////////////////
    generate
        for(genvar i=0; i<8; i=i+1) begin
            assign sk_seed[32*(8-i)-1:32*(7-i)] = reg_dout[2][(32*(i+1)-1):(32*i)];
        end
    endgenerate
    
    BIKE_sampler_private_key #(.THRESHOLD(W/2))
    sample_sk (
        .clk(clk),
        .resetn(sk_sample_resetn),
        .enable(sk_sample_enable),
        .done(sk_sample_done),
        // Keccak
        .keccak_seed(sk_seed),
        .keccak_enable(sk_keccak_enable),
        .keccak_init(sk_keccak_init),
        .keccak_m(sk_keccak_m),
        .keccak_done(keccak_done),
        .keccak_out(keccak_out),
        // Memory I/O
        .h0_rden(sk0_sample_rden),
        .h1_rden(sk1_sample_rden),
        .h0_wren(sk0_sample_wren),
        .h1_wren(sk1_sample_wren),
        .h_addr(sk_sample_addr),
        .h_dout(sk_sample_dout),
        .h0_din(dp_dout0_samp[0]),
        .h1_din(dp_dout1_samp[0]),
        // Compact representation
        .h0_compact_rden(h0_compact_sample_rden),
        .h1_compact_rden(h1_compact_sample_rden),
        .h0_compact_wren(h0_compact_sample_wren),
        .h1_compact_wren(h1_compact_sample_wren),
        .h_compact_addr(h_compact_sample_addr),
        .h_compact_dout(h_compact_sample_dout)
    );            
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Inversion /////////////////////////////////////////////////////////////////
    assign inv_bram_din[0] = dp_dout0[0];
    assign inv_bram_din[1] = dp_dout0[1];
    assign inv_bram_din[2] = dp_dout1[1];
    assign inv_bram_din[3] = dp_dout0[2];
    assign inv_bram_din[4] = dp_dout1[2];
    assign inv_bram_din[5] = dp_dout0[3];
    assign inv_bram_din[6] = dp_dout1[3];
    assign inv_bram_din[7] = dp_dout0[4];
    
    BIKE_inversion_extGCD #(.STEPS(INVERSION_STEPS))
    inversion (
        .clk(clk),
        .resetn(inv_resetn),
        .enable(inv_enable),
        .done(inv_done),
        // Memory
        .mem_rden(inv_bram_rden),
        .mem_wren(inv_bram_wren),
        .mem_addr(inv_bram_addr),
        .mem_dout(inv_bram_dout),
        .mem_din(inv_bram_din)                       
    );        
    //////////////////////////////////////////////////////////////////////////////
    
    
    // KECCAK Core ///////////////////////////////////////////////////////////////
    always @ (*) begin
        case(hash_selection)
            2'b00 : keccak_enable = sk_keccak_enable;
            2'b01 : keccak_enable = h_keccak_enable;
            2'b10 : keccak_enable = l_keccak_enable;
            2'b11 : keccak_enable = k_keccak_enable;
            default : keccak_enable = 1'b0;
        endcase
    end

    always @ (*) begin
        case(hash_selection)
            2'b00 : keccak_init = sk_keccak_init;
            2'b01 : keccak_init = h_keccak_init;
            2'b10 : keccak_init = l_keccak_init;
            2'b11 : keccak_init = k_keccak_init;
            default : keccak_init = 1'b0;
        endcase
    end
    
    always @ (*) begin
        case(hash_selection)
            2'b00 : keccak_m = sk_keccak_m;
            2'b01 : keccak_m = h_keccak_m;
            2'b10 : keccak_m = l_keccak_m;
            2'b11 : keccak_m = k_keccak_m;
            default : keccak_m = {STATE_WIDTH{1'b0}};
        endcase
    end    
    
    KECCAK keccak_core(
        .CLK(clk),
        .RESETN(keccak_resetn),
        .ENABLE(keccak_enable),
        .INIT(keccak_init),
        .DONE(keccak_done),
        .M(keccak_m),
        .KECCAK_OUT(keccak_out)
    );
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Uniform Sampler ///////////////////////////////////////////////////////////
    BIKE_sampler_uniform #(.SAMPLE_LENGTH(L))
    sample_m (
        .CLK(clk),
        .RESETN(m_sample_resetn),
        .ENABLE(m_sample_enable),
        .DONE(m_sample_done),
        // randomness
        .RAND_VALID(rand_valid),
        .RAND_REQU(m_sample_rand_requ),
        .NEW_RAND(rand_din),
        // Memory
        .WREN(m_sample_wren),
        .ADDR(m_sample_addr),
        .DOUT(m_sample_dout)
    );
    //////////////////////////////////////////////////////////////////////////////
    
    
    // H-Function (Error sampler) ////////////////////////////////////////////////
    generate
        for(genvar i=0; i<8; i=i+1) begin
            assign h_seed[32*(8-i)-1:32*(7-i)] = (sel_h == 1'b1) ? reg_dout[3][(32*(i+1)-1):(32*i)] : reg_dout[0][(32*(i+1)-1):(32*i)];
        end
    endgenerate
    
    assign e_sample_din0 = dp_dout0_samp[3]; 
    assign e_sample_din1 = dp_dout1_samp[3]; 
    
    BIKE_sampler_error #(.THRESHOLD(T1))
    h_function (
        .CLK(clk),
        // Control ports
        .RESETN(e_sample_resetn),
        .ENABLE(e_sample_enable),
        .DONE(e_sample_done),
        // Randomness
        .KECCAK_SEED(h_seed),
        .KECCAK_ENABLE(h_keccak_enable),
        .KECCAK_INIT(h_keccak_init),
        .KECCAK_M(h_keccak_m),
        .KECCAK_DONE(keccak_done),
        .KECCAK_OUT(keccak_out),
        // Memory I/O
        .RDEN_1(e_sample_rden0),
        .WREN_1(e_sample_wren0),
        .RDEN_2(e_sample_rden1),
        .WREN_2(e_sample_wren1),
        .ADDR(e_sample_addr),
        .DOUT(e_sample_dout),
        .DIN_1(e_sample_din0),
        .DIN_2(e_sample_din1),
        // compact representation
        .e_compact_rden(e_sample_compact_rden),
        .e_compact_wren(e_sample_compact_wren),
        .e_compact_addr(e_sample_compact_addr),
        .e_compact_dout(e_sample_compact_dout)
    );
    //////////////////////////////////////////////////////////////////////////////
    
    
    // L-Function (Hash Error Vector) ////////////////////////////////////////////
    assign e_l_din0 = (sel_l == 1'b1) ? dp_dout0_samp[5] : dp_dout0_samp[3];
    assign e_l_din1 = (sel_l == 1'b1) ? dp_dout1_samp[5] : dp_dout1_samp[3];
    
    BIKE_L_function l_function (
        .CLK(clk),
        // Control ports
        .RESETN(l_resetn),
        .HASH_EN(l_enable),
        .DONE(l_done),
        // Memory
        .ERROR0_RDEN(e_l_rden0),
        .ERROR1_RDEN(e_l_rden1),
        .ERROR0_ADDR(e_l_addr0),
        .ERROR1_ADDR(e_l_addr1),
        .ERROR0_DIN(e_l_din0),
        .ERROR1_DIN(e_l_din1),
        // KECCAK
        .KECCAK_INIT(l_keccak_init),
        .KECCAK_EN(l_keccak_enable),
        .KECCAK_M(l_keccak_m),
        .KECCAK_DONE(keccak_done),
        // L-Function
        .HASH_IN(keccak_out[1599:1344]),
        .L_VALID(l_valid),
        .L_ADDR(l_addr),
        .L_OUT(l_out)
    );
    //////////////////////////////////////////////////////////////////////////////


    // K-Function (Hash Error Vector) ////////////////////////////////////////////
    assign m_k_din = (sel_k == 1'b1) ? reg_dout[3] : reg_dout[0];
    assign c1_k_din = reg_dout[1];
    
    assign c0_k_din_encaps = T1[0] ? dp_dout0_samp[1] : dp_dout1_samp[1];
    assign c0_k_din_decaps = dp_dout0_samp[2];
    assign c0_k_din = (sel_k == 1'b1) ? c0_k_din_decaps : c0_k_din_encaps;
    
    BIKE_k_function k_function (
        .CLK(clk),
        // Control ports
        .RESETN(k_resetn),
        .HASH_EN(k_enable),
        .DONE(k_done),
        // Data
        .M_L(m_k_din),
        .C1_L(c1_k_din),
        .C0_RDEN(c0_k_rden),
        .C0_ADDR(c0_k_addr),
        .C0(c0_k_din),
        // KECCAK
        .KECCAK_INIT(k_keccak_init),
        .KECCAK_EN(k_keccak_enable),
        .KECCAK_M(k_keccak_m),
        .KECCAK_DONE(keccak_done),
        // L-Function
        .HASH_IN(keccak_out[1599:1344]),
        .K_VALID(k_valid),
        .K_ADDR(k_addr),
        .K_OUT(k_out)
    );
    //////////////////////////////////////////////////////////////////////////////
    

    // Multiplier ////////////////////////////////////////////////////////////////
    assign mul_hw_sparse = (sel_hw_sparse == 1'b1) ? W/2 : T1;

    BIKE_sparse_multiplier_hs  #(.LOG_SIZE_HW($clog2(T1)))
    sparse_multiplier (
        .clk(clk),
        .resetn(mul_resetn),
        .enable(mul_enable),
        .done(mul_done),
        .hw_sparse(mul_hw_sparse),
        .valid(mul_valid),
        // Initial addition
        .apply_init_addtion(mul_init_add),
        .init_add_rden(mul_init_add_rden),
        .init_add_addr(mul_init_add_addr),
        .init_add_din(mul_init_add_din),
        // vector (sparse)
        .vec_rden(mul_vec_rden),
        .vec_addr(mul_vec_addr),
        .vec_din(mul_vec_din0),
        // matrix (dense)
        .mat_rden(mul_mata_rden),
        .mat_addr(mul_mata_addr),
        .mat_din(mul_mata_din0),
        // result a
        .resa_rden(mul_resa_rden),
        .resa_wren(mul_resa_wren),
        .resa_addr(mul_resa_addr),
        .resa_dout(mul_resa_dout),
        .resa_din(mul_resa_din),
        // result b
        .resb_rden(mul_resb_rden),
        .resb_wren(mul_resb_wren),
        .resb_addr(mul_resb_addr),
        .resb_dout(mul_resb_dout),
        .resb_din(mul_resb_din)        
    );
    
    // Assignments for inversion
    parameter ITERATIONS = div_and_floor(2*R_BITS-1, INVERSION_STEPS);
    generate
        if(ITERATIONS[0]) begin
            assign inv_mul_matrixa_din = dp_dout0[3];
        end
        else begin
            assign inv_mul_matrixa_din = dp_dout0[4];
        end
    endgenerate   
    
    // Assignments for encode
    assign enc_mul_done = mul_done;
    
    // Assignments for decaps
    generate
        if(W_DIV_2[0]) begin
            assign syndrome_copy_din = mul_resa_dout;
            assign syndrome_copy_addr = (mul_init_add_rden == 1'b1) ? mul_init_add_addr : mul_resa_addr;
        end
        else begin
            assign syndrome_copy_din = mul_resb_dout;
            assign syndrome_copy_addr = (mul_init_add_rden == 1'b1) ? mul_init_add_addr : mul_resb_addr;
        end
    endgenerate
    assign syndrome_copy_rden = mul_init_add_rden | mul_valid;

    assign mul_init_add_din = (mul_init_add == 1'b1) ? (mul_recompute_syndrome_h1 == 1'b1) ? dp_dout0[4] : dp_dout0[8] : 'b0;

    assign mul_recompute_syndrome_vec_din = (mul_recompute_syndrome_h1 == 1'b1) ? {16'b0, dp_dout1_samp[1][15:0]} : {16'b0, dp_dout0_samp[1][15:0]};
    assign mul_recompute_syndrome_mat_din = (mul_recompute_syndrome_h1 == 1'b1) ? dp_dout1[5] : dp_dout0[5];

    // Contol signals
    always @(*) begin
        case (mul_sel)
            2'b00  : mul_resetn = decaps_mul_resetn;
            2'b01  : mul_resetn = inv_mul_resetn;
            2'b10  : mul_resetn = enc_mul_resetn;
            2'b11  : mul_resetn = decaps_mul_resetn;
            default: mul_resetn = 1'b0;
        endcase
    end

    always @(*) begin
        case (mul_sel)
            2'b00  : mul_enable = decaps_mul_enable;
            2'b01  : mul_enable = inv_mul_enable;
            2'b10  : mul_enable = enc_mul_enable;
            2'b11  : mul_enable = decaps_mul_enable;
            default: mul_enable = 1'b0;
        endcase
    end

    // Multiplication vector
    always @(*) begin
        case (mul_sel)
            2'b00  : mul_vec_din0 = mul_recompute_syndrome_vec_din;
            2'b01  : mul_vec_din0 = dp_dout1_samp[6];
            2'b10  : mul_vec_din0 = dp_dout0_samp[0];
            2'b11  : mul_vec_din0 = {16'b0, dp_dout0_samp[1][15:0]};
            default: mul_vec_din0 = {B_WIDTH{1'b0}};
        endcase
    end   
    
    
    // Multiplication matrix
    always @(*) begin
        case (mul_sel)
            2'b00  : mul_mata_din0 = mul_recompute_syndrome_mat_din;
            2'b01  : mul_mata_din0 = inv_mul_matrixa_din;
            2'b10  : mul_mata_din0 = dp_dout0[2];
            2'b11  : mul_mata_din0 = dp_dout0[2];
            default: mul_mata_din0 = {B_WIDTH{1'b0}};
        endcase
    end      
    
    // Multiplication result    
    always @(*) begin
        case (mul_sel)
            2'b00  : mul_resa_din = dp_dout0[3];
            2'b01  : mul_resa_din = dp_dout0[5];
            2'b10  : mul_resa_din = dp_dout0[1];
            2'b11  : mul_resa_din = dp_dout0[3];
            default: mul_resa_din = {B_WIDTH{1'b0}};
        endcase
    end

    always @(*) begin
        case (mul_sel)
            2'b00  : mul_resb_din = dp_dout1[3];
            2'b01  : mul_resb_din = dp_dout1[5];
            2'b10  : mul_resb_din = dp_dout1[1];
            2'b11  : mul_resb_din = dp_dout1[3];
            default: mul_resb_din = {B_WIDTH{1'b0}};
        endcase
    end
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Hamming Weight ////////////////////////////////////////////////////////////
    generate
        if(W_DIV_2[0]) begin
            always @(*) begin
                case(syndrome_sel)
                    2'b01   : syndrome_hw_din = mul_resa_dout;
                    2'b11   : syndrome_hw_din = syndrome_a_upc_dout;
                    default : syndrome_hw_din = {B_WIDTH{1'b0}};
                endcase 
            end 
        end
        else begin
            always @(*) begin
                case(syndrome_sel)
                    2'b01   : syndrome_hw_din = mul_resb_dout;
                    2'b11   : syndrome_hw_din = syndrome_a_upc_dout;
                    default : syndrome_hw_din = {B_WIDTH{1'b0}};
                endcase 
            end 
        end
    endgenerate
    
    assign cnt_hw_done = (cnt_hw_out == SWORDS-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(LOGSWORDS), .MAX_VALUE(SWORDS))
    cnt_hw (.clk(clk), .resetn(cnt_hw_resetn), .enable(cnt_hw_enable), .cnt_out(cnt_hw_out));
    
    assign hw_mul_din = (((mul_resa_wren == 1'b1) | (mul_resb_wren == 1'b1)) & (mul_valid == 1'b1)) ? syndrome_hw_din : {B_WIDTH{1'b0}};
    assign hw_bfiter_din = ((e0_bfiter_wren == 1'b1) | (e1_bfiter_wren == 1'b1)) ? e_bfiter_dout : {B_WIDTH{1'b0}};
    
    always @ (*) begin
        case(hw_sel)
            2'b01   : hw_din = hw_mul_din;
            2'b10   : hw_din = hw_bfiter_din;
            2'b11   : hw_din = compe_xor;
            default : hw_din = {32{1'b0}};
        endcase
    end
    
    always @ (posedge clk) begin
        hw_enable_d <= hw_enable;
    end
    
    BIKE_hamming_weight hamming_weight(
        .clk(clk),
        .enable(hw_enable_d),
        .resetn(hw_resetn),
        // data
        .din(hw_din),
        .dout(hw_dout)
    );
    
    // indicates if the decoder succeded - if succeded decoder_res_out = 1'b1;
    assign decoder_res_in = (hw_dout == 0) ? 1'b1 : 1'b0;
    always @ (posedge clk) begin
        if(~decoder_res_resetn) begin
            decoder_res_out <= 1'b0;
        end
        else begin
            if(decoder_res_enable) begin
                decoder_res_out <= decoder_res_in;
            end
            else begin
                decoder_res_out <= decoder_res_out;
            end
        end
    end
    
    // indicates if the Hamming weight of the decoded error vector is equal to T1 - if it is equal HW_E_OUT=1
    assign hw_e_in = (hw_dout == T1) ? 1'b1 : 1'b0;
    always @ (posedge clk) begin
        if(~resetn) begin
            hw_e_out <= 1'b0;
        end
        else begin
            if(hw_check_e) begin
                hw_e_out <= hw_e_in;
            end
            else begin
                hw_e_out <= hw_e_out;
            end
        end
    end
    
    //  indicates if H(m')=(e0',e1') - if equal HW_COMPARE_OUT = '1'
    always @ (posedge clk) begin
        if(~hw_compare_rstn) begin
            hw_compare_out <= 1'b0;
        end
        else begin
            if(hw_compare_en) begin
                hw_compare_out <= decoder_res_in;
            end
            else begin
                hw_compare_out <= hw_compare_out;
            end
        end
    end    
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Threshold /////////////////////////////////////////////////////////////////
    assign th_din = hw_dout;
    
    BIKE_compute_threshold th(
        .clk(clk),
        .enable(th_enable),
        .s(th_din),
        .t(th_dout)
    );
    
    // counter is used to wait until all data has left the pipeline of the Hamming weight module
    assign cnt_hwth_done = (cnt_hwth_out == LOGBWIDTH-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(LOGBWIDTH+2))), .MAX_VALUE(LOGBWIDTH+2))
    cnt_hw_th (.clk(clk), .enable(cnt_hwth_en), .resetn(cnt_hwth_rstn), .cnt_out(cnt_hwth_out)); 
    //////////////////////////////////////////////////////////////////////////////
    
    
    // BFIter ////////////////////////////////////////////////////////////////////
    // counts the number of iterations of the BGF decoder
    assign cnt_nbiter_done = (cnt_nbiter_out == NBITER) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(int'($clog2(NBITER+1))), .MAX_VALUE(NBITER))
    cnt_nbiter (.clk(clk), .enable(cnt_nbiter_en), .resetn(cnt_nbiter_rstn), .cnt_out(cnt_nbiter_out));
    
    always @(*) begin
        case(bfiter_sel)
            2'b00   : th_bfiter_in = th_dout;
            2'b01   : th_bfiter_in = (W/2+1)/2+1;
            2'b10   : th_bfiter_in = (W/2+1)/2+1;
            2'b11   : th_bfiter_in = th_dout;
            default : th_bfiter_in = 'b0; 
        endcase
    end

    assign syndrome_upc_a_din = dp_dout0[4];
    assign syndrome_upc_b_din = dp_dout1[4];
    
    BIKE_bfiter_generic bfiter(
        .CLK(clk),
        // Control ports
        .RESETN(bfiter_resetn),
        .ENABLE(bfiter_enable),
        .DONE(bfiter_done),
        .MODE_SEL(bfiter_sel),
        // Threshold
        .TH(th_bfiter_in),
        // Syndrome
        .SYNDROME_RDEN(syndrome_upc_rden),
        .SYNDROME_WREN(syndrome_upc_wren),
        .SYNDROME_A_ADDR(syndrome_upc_a_addr),
        .SYNDROME_A_DIN(syndrome_upc_a_din),
        .SYNDROME_A_DOUT(syndrome_upc_a_dout),
        .SYNDROME_B_ADDR(syndrome_upc_b_addr),
        .SYNDROME_B_DIN(syndrome_upc_b_din),
        .SYNDROME_B_DOUT(syndrome_upc_b_dout),   
        // Secret Key
        .SK0_RDEN(sk0_bfiter_rden), 
        .SK1_RDEN(sk1_bfiter_rden), 
        .SK0_WREN(sk0_bfiter_wren), 
        .SK1_WREN(sk1_bfiter_wren),
        .SK_ADDR(sk_bfiter_addr),
        .SK_DOUT(sk_bfiter_dout),
        .SK0_DIN(dp_dout0_samp[1]), 
        .SK1_DIN(dp_dout1_samp[1]), 
        // Error
        .E0_RDEN(e0_bfiter_rden),
        .E1_RDEN(e1_bfiter_rden),
        .E0_WREN(e0_bfiter_wren),
        .E1_WREN(e1_bfiter_wren),
        .E_ADDR(e_bfiter_addr),
        .E_DOUT(e_bfiter_dout),
        .E0_DIN(dp_dout0[5]),
        .E1_DIN(dp_dout1[5]),
        // Black
        .BLACK0_RDEN(black0_bfiter_rden),
        .BLACK1_RDEN(black1_bfiter_rden),
        .BLACK0_WREN(black0_bfiter_wren),
        .BLACK1_WREN(black1_bfiter_wren),
        .BLACK_ADDR(black_bfiter_addr),
        .BLACK_DOUT(black_bfiter_dout),
        .BLACK0_DIN(dp_dout0[6]),
        .BLACK1_DIN(dp_dout1[6]), 
        // Gray
        .GRAY0_RDEN(gray0_bfiter_rden),
        .GRAY1_RDEN(gray1_bfiter_rden),
        .GRAY0_WREN(gray0_bfiter_wren),
        .GRAY1_WREN(gray1_bfiter_wren),
        .GRAY_ADDR(gray_bfiter_addr),
        .GRAY_DOUT(gray_bfiter_dout),
        .GRAY0_DIN(dp_dout0[7]),
        .GRAY1_DIN(dp_dout1[7])
    );
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Comparison and copy error vectors /////////////////////////////////////////
    assign cnt_compe_done = (cnt_compe_out == SWORDS-1) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(LOGSWORDS), .MAX_VALUE(SWORDS-1))
    cnt_compe (.clk(clk), .enable(cnt_compe_enable), .resetn(cnt_compe_resetn), .cnt_out(cnt_compe_out));
    
    always @ (posedge clk) begin
        if(~resetn) begin
            cnt_copy_enable <= 1'b0;
        end
        else begin
            cnt_copy_enable <= cnt_compe_enable;
        end
    end
    
    assign cnt_copy_done = (cnt_copy_out == SWORDS-2) ? 1'b1 : 1'b0;
    BIKE_counter_inc #(.SIZE(LOGSWORDS), .MAX_VALUE(SWORDS-1))
    cnt_copy (.clk(clk), .enable(cnt_copy_enable), .resetn(cnt_copy_resetn), .cnt_out(cnt_copy_out));
    
    assign e_copy_wren = decoder_res_out & hw_e_out;
    
    // comparison
    always @ (posedge clk) begin
        if(~resetn) begin
            sel_comp_error_poly <= 1'b0;
        end
        else begin
            sel_comp_error_poly <= e0_compe_rden;
        end
    end
    
    assign compe_dina = (sel_comp_error_poly == 1'b1) ? dp_dout0[5] : dp_dout1[5];
    assign compe_dinb = (sel_comp_error_poly == 1'b1) ? dp_dout0[0] : dp_dout1[0];
    
    assign compe_xor = compe_dina ^ compe_dinb;
    //////////////////////////////////////////////////////////////////////////////
    
    
    // Output ////////////////////////////////////////////////////////////////////
    assign cnt_out_l_done       = (cnt_out_out == 7) ? 1'b1 : 1'b0;
    assign cnt_out_poly_done    = (cnt_out_out == DWORDS-1) ? 1'b1 : 1'b0;
    
    BIKE_counter_inc #(.SIZE(LOGDWORDS), .MAX_VALUE(DWORDS-1))
    cnt_out (.clk(clk), .enable(cnt_out_enable), .resetn(cnt_out_resetn), .cnt_out(cnt_out_out));
    
    always @ (posedge clk) begin
        dout_addr_d             <= cnt_out_out;
        dout_valid              <= dout_valid_intern;
    end
    
    assign dout_addr = dout_addr_d;
    
    generate if(T1[0]) begin
        assign c0_dout = dp_dout0_samp[1];
    end else begin
        assign c0_dout = dp_dout1_samp[1];
    end endgenerate

    parameter TEMP = W/2;
    generate if(TEMP[0]) begin
        assign h_dout = dp_dout0_samp[5];
    end else begin
        assign h_dout = dp_dout1_samp[5];
    end endgenerate
    
    always @(*) begin
        case(request_data)
            tx_h0       : dout = dp_dout0_samp[6];
            tx_h1       : dout = dp_dout1_samp[6];
            tx_sigma    : dout = m_reg_dout[dout_addr_d];
            tx_h        : dout = h_dout;
            tx_c0       : dout = c0_dout;
            tx_c1       : dout = c1_reg_dout[dout_addr_d];  
            tx_k        : dout = k_reg_dout[dout_addr_d]; 
            default     : dout = 32'b0;
        endcase
    end

    //////////////////////////////////////////////////////////////////////////////
    
    
    // FINITE STATE MACHINE (FSM) ////////////////////////////////////////////////
    localparam [5:0]
        s_idle                          =  0,
        s_load_data                     =  1,
        s_keygen_sample_seed            =  2,
        s_keygen_sample_sk              =  3,
        s_keygen_sample_sigma           =  4,
        s_keygen_inversion              =  5,
        s_keygen_multiplication         =  6,
        s_encaps_sample_m               =  7,
        s_encaps_reset_keccak           =  8,
        s_encaps_sample_e               =  9,
        s_encaps_hash_encode            = 10,
        s_encaps_mul                    = 11,
        s_encaps_hash_mc                = 12,
        s_decaps_compute_syndrome       = 13,
        s_decaps_hw_th                  = 14,
        s_decaps_bfiter                 = 15,
        s_decaps_bfiter_bg              = 16,
        s_decaps_bfiter_black           = 17,
        s_decaps_bfiter_gray            = 18,
        s_decaps_recompute_syndrome_h0  = 19,
        s_decaps_recompute_syndrome_rst = 20,
        s_decaps_recompute_syndrome_h1  = 21,
        s_decaps_inc_nbiter_cnt         = 22,
        s_decaps_check_progress         = 23,
        s_decaps_hamming_weight         = 24,
        s_decaps_hamming_weight_rst     = 25,
        s_decaps_hash_l                 = 26,
        s_decaps_reset_keccak           = 27,
        s_decaps_h_function             = 28,
        s_decaps_compe0                 = 29,
        s_decaps_compe1                 = 30,
        s_decaps_comp_hw                = 31,
        s_decaps_k_function             = 32,
        s_done                          = 33,
        s_return_l_data                 = 34,
        s_return_poly_data              = 35,
        s_return_compact_data           = 36,
        s_return_delay                  = 37,
        s_reset_memory                  = 38;
        
    reg [5:0] state_reg, state_next;
    
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
                if(din_load) begin                      // load data
                    state_next      = s_load_data;
                end
                else if(instruction == 3'b001) begin    // start key generation
                    state_next      = s_keygen_sample_seed;
                end
                else if(instruction == 3'b010) begin    // start encapsulation
                    state_next      = s_encaps_sample_m;
                end
                else if(instruction == 3'b100) begin    // start decaps
                    state_next      = s_decaps_compute_syndrome;
                end
                else if(request_data == tx_sigma || request_data == tx_c1 || request_data == tx_k) begin
                    state_next      = s_return_l_data;
                end
                else if(request_data == tx_h || request_data == tx_c0) begin
                    state_next      = s_return_poly_data;
                end
                else if(request_data == tx_h0 || request_data == tx_h1) begin
                    state_next      = s_return_compact_data;
                end                
                else if(request_done) begin
                    state_next      = s_reset_memory;
                end
                else begin                              // idle
                    state_next      = s_idle;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_keygen_sample_seed : begin
                if (m_sample_done) begin
                    state_next      = s_keygen_sample_sk;
                end
                else begin
                    state_next      = s_keygen_sample_seed;
                end
            end
            // -----------------------------------
            
            // -----------------------------------
            s_keygen_sample_sk : begin
                if (sk_sample_done) begin
                    state_next      = s_keygen_sample_sigma;
                end
                else begin
                    state_next      = s_keygen_sample_sk;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_keygen_sample_sigma : begin
                if (m_sample_done) begin
                    state_next      = s_keygen_inversion;
                end
                else begin
                    state_next      = s_keygen_sample_sigma;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_keygen_inversion : begin
                if (inv_done) begin
                    state_next      = s_keygen_multiplication;
                end
                else begin
                    state_next      = s_keygen_inversion;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_keygen_multiplication : begin
                if (mul_done) begin
                    state_next      = s_done;
                end
                else begin
                    state_next      = s_keygen_multiplication;
                end
            end
            // -----------------------------------
                                                                                                            
            // -----------------------------------
            s_encaps_sample_m : begin
                if (m_sample_done == 1'b1) begin
                    state_next      = s_encaps_sample_e;
                end
                else begin
                    state_next      = s_encaps_sample_m;
                end
            end
            // -----------------------------------
            
            // -----------------------------------
            s_encaps_sample_e : begin
                if(e_sample_done == 1'b1) begin
                    state_next      = s_encaps_reset_keccak;
                end
                else begin
                    state_next      = s_encaps_sample_e;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_encaps_reset_keccak : begin
                state_next          = s_encaps_hash_encode;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_encaps_hash_encode : begin
                if(l_done == 1'b1) begin
                    state_next      = s_encaps_mul;
                end
                else begin
                    state_next      = s_encaps_hash_encode;
                end
            end
            // -----------------------------------
                        
            // -----------------------------------
            s_encaps_mul : begin
                if(mul_done) begin
                    state_next      = s_encaps_hash_mc;
                end
                else begin
                    state_next      = s_encaps_mul;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_encaps_hash_mc : begin
                if(k_done) begin
                    state_next      = s_done;
                end
                else begin
                    state_next      = s_encaps_hash_mc;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_compute_syndrome : begin
                if(mul_done) begin
                    state_next      = s_decaps_hw_th;
                end
                else begin
                    state_next      = s_decaps_compute_syndrome;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_hw_th : begin
                if(cnt_hwth_done) begin
                    state_next      = s_decaps_check_progress;
                end
                else begin
                    state_next      = s_decaps_hw_th;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_check_progress : begin
                if(cnt_nbiter_done) begin
                    state_next      = s_decaps_hash_l;
                end
                else if(cnt_nbiter_out == 0) begin
                    state_next      = s_decaps_bfiter_bg;
                end
                else if(cnt_nbiter_out == 1) begin
                    state_next      = s_decaps_bfiter_black;
                end
                else if(cnt_nbiter_out == 2) begin
                    state_next      = s_decaps_bfiter_gray;
                end
                else begin
                    state_next      = s_decaps_bfiter;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_bfiter_bg : begin
                if(bfiter_done) begin
                    state_next      = s_decaps_recompute_syndrome_h0;
                end
                else begin
                    state_next      = s_decaps_bfiter_bg;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_bfiter_black : begin
                if(bfiter_done) begin
                    state_next      = s_decaps_recompute_syndrome_h0;
                end
                else begin
                    state_next      = s_decaps_bfiter_black;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_bfiter_gray : begin
                if(bfiter_done) begin
                    state_next      = s_decaps_recompute_syndrome_h0;
                end
                else begin
                    state_next      = s_decaps_bfiter_gray;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_bfiter : begin
                if(bfiter_done) begin
                    state_next      = s_decaps_hamming_weight;
                end
                else begin
                    state_next      = s_decaps_bfiter;
                end
            end
            // -----------------------------------
                                    
            // -----------------------------------
            s_decaps_recompute_syndrome_h0 : begin
                if(mul_done) begin
                    state_next      = s_decaps_recompute_syndrome_rst;
                end
                else begin
                    state_next      = s_decaps_recompute_syndrome_h0;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_recompute_syndrome_rst : begin
                state_next          = s_decaps_recompute_syndrome_h1;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_recompute_syndrome_h1 : begin
                if(mul_done) begin
                    state_next      = s_decaps_inc_nbiter_cnt;
                end
                else begin
                    state_next      = s_decaps_recompute_syndrome_h1;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_inc_nbiter_cnt : begin
                state_next          = s_decaps_hw_th;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_decaps_hamming_weight : begin
                if(cnt_hwth_done) begin
                    state_next      = s_decaps_hamming_weight_rst;
                end
                else begin
                    state_next      = s_decaps_hamming_weight;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_hamming_weight_rst : begin
                state_next      = s_decaps_recompute_syndrome_h0;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_hash_l : begin
                if(l_done) begin
                    state_next  = s_decaps_reset_keccak;
                end 
                else begin
                    state_next  = s_decaps_hash_l;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_reset_keccak : begin
                state_next      = s_decaps_h_function;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_decaps_h_function : begin
                if(e_sample_done) begin
                    state_next  = s_decaps_compe0;
                end 
                else begin
                    state_next  = s_decaps_h_function;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_compe0 : begin
                if(cnt_compe_done) begin
                    state_next  = s_decaps_compe1;
                end 
                else begin
                    state_next  = s_decaps_compe0;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_compe1 : begin
                if(cnt_compe_done) begin
                    state_next  = s_decaps_comp_hw;
                end 
                else begin
                    state_next  = s_decaps_compe1;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_comp_hw : begin
                if(cnt_hwth_done) begin
                    state_next  = s_decaps_k_function;
                end 
                else begin
                    state_next  = s_decaps_comp_hw;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_k_function : begin
                if(k_done) begin
                    state_next  = s_done;
                end 
                else begin
                    state_next  = s_decaps_k_function;
                end
            end
            // -----------------------------------
                                                                                                                                                                        
            // -----------------------------------
            s_load_data : begin
                if(din_done) begin
                    state_next      = s_idle;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_return_l_data : begin
                if(cnt_out_l_done) begin
                    state_next      = s_return_delay;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_return_poly_data : begin
                if(cnt_out_poly_done) begin
                    state_next      = s_return_delay;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_return_compact_data : begin
                if(cnt_out_out == W/2-1) begin
                    state_next      = s_return_delay;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_reset_memory : begin
                if(cnt_compe_done) begin
                    state_next      = s_done;
                end
                else begin
                    state_next      = s_reset_memory;
                end
            end
            // -----------------------------------

            // -----------------------------------
            s_return_delay : begin
                state_next          = s_done;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_done : begin
                state_next          = s_idle;
            end
            // -----------------------------------
            
         endcase     
    end
    
    // output logic
    always @(state_reg) begin
        // default outputs
        // Global control
        busy                        = 1'b0;
        done                        = 1'b0;
        
        // Data-In
        din_ready                   = 1'b0;
        data_load_en                = 1'b0;
        
        // BRAM
        dp_selection_fsm[0]         = 'b0;
        dp_selection_fsm[1]         = 'b0;
        dp_selection_fsm[2]         = 'b0;
        dp_selection_fsm[3]         = 'b0;
        dp_selection_fsm[4]         = 'b0;
        dp_selection_fsm[5]         = 'b0;
        dp_selection_fsm[6]         = 'b0;
        dp_selection_fsm[7]         = 'b0;
        dp_selection_fsm[8]         = 'b0;
        
        // Sample secret key
        sk_sample_enable            = 1'b0;
        sk_sample_resetn            = 1'b0;
        sample_seed                 = 1'b0;
        
        // KECCAK
        hash_selection              = 2'b00;
        keccak_resetn               = 1'b0;
        
        // Sample message 
        m_sample_resetn             = 1'b0;
        m_sample_enable             = 1'b0;
        
        // H-Function (Sample error)
        sel_h                       = 1'b0;
        e_sample_resetn             = 1'b0;
        e_sample_enable             = 1'b0;
        
        // L-Function
        sel_l                       = 1'b0;
        l_enable                    = 1'b0;
        l_resetn                    = 1'b0;
        // K-Function
        sel_k                       = 1'b0;    
        k_enable                    = 1'b0;
        k_resetn                    = 1'b0;
        
        // Inversion 
        inv_resetn                  = 1'b0;
        inv_enable                  = 1'b0;
        inv_mul_done                = 1'b0;
                
        // Multiplier
        mul_sel                     = 2'b00;
        sel_hw_sparse               = 1'b0;
        mul_omit_init_add           = 1'b0;
        mul_init_add                = 1'b0;
        mul_recompute_syndrome_h1   = 1'b0;
        enc_mul_resetn              = 1'b0;
        enc_mul_enable              = 1'b0;
        inv_mul_enable              = 1'b0;
        inv_mul_resetn              = 1'b0;
        decaps_mul_resetn           = 1'b0;
        decaps_mul_enable           = 1'b0;
        
        // Copy Memory
        mem_copy_resetn             = 1'b0;
        mem_copy_enable             = 1'b0;
        // Hamming Weight
        cnt_hw_enable               = 1'b0;
        cnt_hw_resetn               = 1'b0;
        hw_enable                   = 1'b0;
        hw_resetn                   = 1'b0;
        hw_sel                      = 2'b00;
        syndrome_sel                = 2'b00;
        
        decoder_res_resetn          = 1'b0;
        decoder_res_enable          = 1'b0;
        
        hw_check_e                  = 1'b0;
        
        // Threshold
        th_enable                   = 1'b0;
        
        cnt_hwth_rstn               = 1'b0;
        cnt_hwth_en                 = 1'b0;     
        
        // BFIter
        cnt_nbiter_en               = 1'b0;
        cnt_nbiter_rstn             = 1'b0;
        
        bfiter_resetn               = 1'b0;
        bfiter_enable               = 1'b0;
        bfiter_sel                  = 2'b00;
        
        cnt_copyh01_resetn          = 1'b0;
        cnt_copyh01_enable          = 1'b0;
        
        // compare error vector
        cnt_compe_resetn            = 1'b0;
        cnt_compe_enable            = 1'b0;
        e0_compe_rden               = 1'b0;
        e1_compe_rden               = 1'b0;
        hw_compare_rstn             = 1'b0;
        hw_compare_en               = 1'b0;
        
        // Copy error vector
        cnt_copy_resetn             = 1'b0;
        
        // Output
        sel_out                     = 1'b0;
        dout_valid_intern           = 1'b0;
        cnt_out_enable              = 1'b0;
        cnt_out_resetn              = 1'b0;
        
        case (state_reg)
            // -----------------------------------
            s_idle : begin
                din_ready           = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_load_data : begin
                busy                = 1'b1;
                data_load_en        = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_keygen_sample_seed : begin
                busy                = 1'b1;
                
                sample_seed         = 1'b1;
                m_sample_resetn     = 1'b1;
                m_sample_enable     = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_keygen_sample_sk : begin
                busy                = 1'b1;
                
                dp_selection_fsm[0] = 5'b00001;
                dp_selection_fsm[6] = 5'b01001;
                
                keccak_resetn       = 1'b1;
                
                sk_sample_resetn    = 1'b1;
                sk_sample_enable    = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_keygen_sample_sigma : begin
                busy                = 1'b1;
                
                m_sample_resetn     = 1'b1;
                m_sample_enable     = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_keygen_inversion : begin
                busy                = 1'b1;
                
                dp_selection_fsm[0] = 5'b01001;
                dp_selection_fsm[1] = 5'b01001;
                dp_selection_fsm[2] = 5'b01001;
                dp_selection_fsm[3] = 5'b01001;
                dp_selection_fsm[4] = 5'b01001;
                
                inv_enable          = 1'b1;
                inv_resetn          = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_keygen_multiplication : begin
                busy                = 1'b1;
                
                dp_selection_fsm[3] = 5'b10001;
                dp_selection_fsm[4] = 5'b10001;
                dp_selection_fsm[5] = 5'b01001;
                dp_selection_fsm[6] = 5'b10001;
                
                mul_sel             = 2'b01;
                inv_mul_enable      = 1'b1;
                inv_mul_resetn      = 1'b1;
                sel_hw_sparse       = 1'b1;                
            end
            // -----------------------------------
                                                                                    
            // -----------------------------------
            s_encaps_sample_m : begin
                busy                = 1'b1;
                                
                m_sample_resetn     = 1'b1;
                m_sample_enable     = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_encaps_sample_e : begin
                busy                = 1'b1;
                
                dp_selection_fsm[0] = 5'b01010;
                dp_selection_fsm[3] = 5'b01010;
                
                hash_selection      = 2'b01;
                keccak_resetn       = 1'b1;
                
                e_sample_resetn     = 1'b1;
                e_sample_enable     = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_encaps_reset_keccak : begin
                busy                = 1'b1;
            end
            // -----------------------------------            
            
            // -----------------------------------
            s_encaps_hash_encode : begin
                busy                = 1'b1;
                
                // L-Function
                dp_selection_fsm[3] = 5'b10010;
                
                hash_selection      = 2'b10;
                keccak_resetn       = 1'b1;
                
                l_resetn            = 1'b1;
                l_enable            = 1'b1;
                
                // Multiplicaton
                dp_selection_fsm[0] = 5'b10010;
                dp_selection_fsm[1] = 5'b01010;
                dp_selection_fsm[2] = 5'b01010;
                
                mul_sel             = 2'b10;
                enc_mul_resetn      = 1'b1;
                enc_mul_enable      = 1'b1;
            end
            // -----------------------------------            
            
            // -----------------------------------
            s_encaps_mul : begin
                busy                = 1'b1;
                
                dp_selection_fsm[0] = 5'b10010;
                dp_selection_fsm[1] = 5'b01010;
                dp_selection_fsm[2] = 5'b01010;
                
                mul_sel             = 2'b10;
                enc_mul_resetn      = 1'b1;
                enc_mul_enable      = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_encaps_hash_mc : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[0]     = 5'b11010;
                dp_selection_fsm[1]     = 5'b10010;
                
                hash_selection          = 2'b11;
                keccak_resetn           = 1'b1;
                
                k_resetn                = 1'b1;
                k_enable                = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_compute_syndrome : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b10100;
                dp_selection_fsm[2]     = 5'b01100;
                dp_selection_fsm[3]     = 5'b00100;
                dp_selection_fsm[4]     = 5'b00100;
                dp_selection_fsm[8]     = 5'b00100;
                
                mul_sel                 = 2'b11;
                sel_hw_sparse           = 1'b1;
                decaps_mul_resetn       = 1'b1;
                decaps_mul_enable       = 1'b1;
                
                syndrome_sel            = 2'b01;
                hw_sel                  = 2'b01;
                
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_recompute_syndrome_h0 : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b10100;
                dp_selection_fsm[3]     = 5'b00100;
                dp_selection_fsm[4]     = 5'b00100;
                dp_selection_fsm[5]     = 5'b01100;
                dp_selection_fsm[8]     = 5'b01100;
                
                mul_sel                 = 2'b00;
                mul_init_add            = 1'b1;    
                decaps_mul_resetn       = 1'b1;
                decaps_mul_enable       = 1'b1;               
                sel_hw_sparse           = 1'b1;
                
                // syndrome_sel            = 2'b01;
                // hw_sel                  = 2'b01;
                
                // hw_resetn               = 1'b1;
                // hw_enable               = 1'b1;
                
                cnt_nbiter_rstn         = 1'b1;
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_recompute_syndrome_rst : begin
                busy                    = 1'b1;
                                
                cnt_nbiter_rstn         = 1'b1;
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_recompute_syndrome_h1 : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b10100;
                dp_selection_fsm[3]     = 5'b00100;
                dp_selection_fsm[4]     = 5'b00100;
                dp_selection_fsm[5]     = 5'b01100;
                
                mul_sel                 = 2'b00;
                mul_init_add            = 1'b1;    
                decaps_mul_resetn       = 1'b1;
                decaps_mul_enable       = 1'b1;
                mul_recompute_syndrome_h1 = 1'b1;
                sel_hw_sparse           = 1'b1;
                
                syndrome_sel            = 2'b01;
                hw_sel                  = 2'b01;
                
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                cnt_nbiter_rstn         = 1'b1;
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_inc_nbiter_cnt : begin
                busy                    = 1'b1;
                
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                th_enable               = 1'b1;
                
                cnt_hwth_rstn           = 1'b1;
                cnt_hwth_en             = 1'b1;      
                
                cnt_nbiter_rstn         = 1'b1;
                cnt_nbiter_en           = 1'b1;           
            end
            // ----------------------------------- 
                        
            // -----------------------------------
            s_decaps_hw_th : begin
                busy                    = 1'b1;
                
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                th_enable               = 1'b1;
                
                cnt_hwth_rstn           = 1'b1;
                cnt_hwth_en             = 1'b1;      
                
                cnt_nbiter_rstn         = 1'b1;     
                
                decoder_res_resetn      = 1'b1;      
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_check_progress : begin
                busy                    = 1'b1;
                
                decoder_res_resetn      = 1'b1;
                decoder_res_enable      = 1'b1;     
                 
                cnt_nbiter_rstn         = 1'b1;
            end
            // ----------------------------------- 
            
            // -----------------------------------
            s_decaps_bfiter_bg : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b11100;
                dp_selection_fsm[4]     = 5'b01100;
                dp_selection_fsm[5]     = 5'b00100;
                dp_selection_fsm[6]     = 5'b00100;
                dp_selection_fsm[7]     = 5'b00100;
                
                syndrome_sel            = 2'b11;
                
                // Bfiter
                bfiter_resetn           = 1'b1;
                bfiter_enable           = 1'b1;
                bfiter_sel              = 2'b00;
                
                // Counter
                cnt_nbiter_rstn         = 1'b1;             
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_bfiter_black : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b11100;
                dp_selection_fsm[4]     = 5'b01100;
                dp_selection_fsm[5]     = 5'b00100;
                dp_selection_fsm[6]     = 5'b00100;
                dp_selection_fsm[7]     = 5'b00100;
                
                syndrome_sel            = 2'b11;
                
                // Bfiter
                bfiter_resetn           = 1'b1;
                bfiter_enable           = 1'b1;
                bfiter_sel              = 2'b01;
                
                // Counter
                cnt_nbiter_rstn         = 1'b1;             
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_bfiter_gray : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b11100;
                dp_selection_fsm[4]     = 5'b01100;
                dp_selection_fsm[5]     = 5'b00100;
                dp_selection_fsm[6]     = 5'b00100;
                dp_selection_fsm[7]     = 5'b00100;
                
                syndrome_sel            = 2'b11;
                
                // Bfiter
                bfiter_resetn           = 1'b1;
                bfiter_enable           = 1'b1;
                bfiter_sel              = 2'b10;
                
                // Counter
                cnt_nbiter_rstn         = 1'b1;             
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_bfiter : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[1]     = 5'b11100;
                dp_selection_fsm[4]     = 5'b01100;
                dp_selection_fsm[5]     = 5'b00100;
                dp_selection_fsm[6]     = 5'b00100;
                dp_selection_fsm[7]     = 5'b00100;
                
                syndrome_sel            = 2'b11;
                hw_sel                  = 2'b10;
                
                // Bfiter
                bfiter_resetn           = 1'b1;
                bfiter_enable           = 1'b1;
                bfiter_sel              = 2'b11;
                
                // Counter
                cnt_nbiter_rstn         = 1'b1;           
                
                // Hamming weight
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                decoder_res_resetn      = 1'b1;   
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_hamming_weight : begin
                busy                    = 1'b1;
                
                hw_sel                  = 2'b10;

                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                hw_check_e              = 1'b1;
                
                cnt_hwth_rstn           = 1'b1;
                cnt_hwth_en             = 1'b1;   
                                
                // Counter
                cnt_nbiter_rstn         = 1'b1;               
            end
            // -----------------------------------   

            // -----------------------------------
            s_decaps_hamming_weight_rst : begin
                busy                    = 1'b1;  
                
                // Counter
                cnt_nbiter_rstn         = 1'b1;          
            end
            // -----------------------------------   

            // -----------------------------------
            s_decaps_hash_l : begin
                busy                    = 1'b1;  
                
                // L-Function
                sel_l                   = 1'b1;
                dp_selection_fsm[5]     = 5'b10100;
                
                hash_selection          = 2'b10;
                keccak_resetn           = 1'b1;
                
                l_resetn                = 1'b1;
                l_enable                = 1'b1;
                  
                // Check
                decoder_res_resetn      = 1'b1;        
            end
            // ----------------------------------- 

            // -----------------------------------
            s_decaps_reset_keccak : begin
                busy                    = 1'b1;      
            end
            // ----------------------------------- 
                        
            // -----------------------------------
            s_decaps_h_function : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[0]     = 5'b00100;
                
                hash_selection          = 2'b01;
                keccak_resetn           = 1'b1;
                
                // H-Function
                sel_h                   = 1'b1;
                e_sample_resetn         = 1'b1;
                e_sample_enable         = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_compe0 : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[0]     = 5'b11100;
                dp_selection_fsm[5]     = 5'b11100;
                
                // Hamming Weight
                hw_sel                  = 2'b11;
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                // Counter
                cnt_compe_resetn        = 1'b1;
                cnt_compe_enable        = 1'b1;
                
                // Comparison
                e0_compe_rden           = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_compe1 : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[0]     = 5'b11100;
                dp_selection_fsm[5]     = 5'b11100;
                
                // Hamming Weight
                hw_sel                  = 2'b11;
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                
                // Counter
                cnt_compe_resetn        = 1'b1;
                cnt_compe_enable        = 1'b1;
                
                // Comparison
                e1_compe_rden           = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_comp_hw : begin
                busy                    = 1'b1;
                
                // Hamming Weight
                hw_resetn               = 1'b1;
                hw_enable               = 1'b1;
                hw_compare_rstn         = 1'b1;
                hw_compare_en           = 1'b1;
                 
                // Counter
                cnt_hwth_rstn           = 1'b1;
                cnt_hwth_en             = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_decaps_k_function : begin
                busy                    = 1'b1;
                
                // Memory
                dp_selection_fsm[2]     = 5'b10100;
                
                // K-Function
                sel_k                   = 1'b1;
                hash_selection          = 2'b11;
                keccak_resetn           = 1'b1;
                
                k_resetn                = 1'b1;
                k_enable                = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_return_l_data : begin
                busy                    = 1'b1;
                
                sel_out                 = 1'b1;
                
                dout_valid_intern       = 1'b1;
                cnt_out_enable          = 1'b1;
                cnt_out_resetn          = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_return_poly_data : begin
                busy                    = 1'b1;
                
                dout_valid_intern       = 1'b1;
                cnt_out_enable          = 1'b1;
                cnt_out_resetn          = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_return_compact_data : begin
                busy                    = 1'b1;
                
                dout_valid_intern       = 1'b1;
                cnt_out_enable          = 1'b1;
                cnt_out_resetn          = 1'b1;
            end
            // -----------------------------------

            // -----------------------------------
            s_return_delay : begin
                busy                    = 1'b1;
            end
            // -----------------------------------
            
            // -----------------------------------
            s_reset_memory : begin
                busy                    = 1'b1;
                
                dp_selection_fsm[0]     = 5'b00111;
                dp_selection_fsm[1]     = 5'b00111;
                dp_selection_fsm[2]     = 5'b00111;
                dp_selection_fsm[3]     = 5'b00111;
                dp_selection_fsm[4]     = 5'b00111;
                dp_selection_fsm[5]     = 5'b00111;
                dp_selection_fsm[6]     = 5'b00111;
                dp_selection_fsm[7]     = 5'b00111;
                dp_selection_fsm[8]     = 5'b00111;

                cnt_compe_enable        = 1'b1;
                cnt_compe_resetn        = 1'b1;
            end
            // -----------------------------------
                                                                                                                                                                                                                                 
            // -----------------------------------
            s_done : begin
                done                    = 1'b1;
            end
            // -----------------------------------
        endcase
    end
    //////////////////////////////////////////////////////////////////////////////
    
endmodule
