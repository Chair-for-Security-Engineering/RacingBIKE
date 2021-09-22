`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         21.09.2021 
// Module Name:         BIKE_GENERIC_BRAM_SHARED
// Description:         This module is used to store two polynomials in one BRAM.
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



// Imports ///////////////////////////////////////////////////////////////////////
import BIKE_PACKAGE::*;



// Module ////////////////////////////////////////////////////////////////////////
module BIKE_GENERIC_BRAM_SHARED(
    input  clk,
    input  resetn,
    input  sampling,
    // Sampling
    input  ren0_samp,
    input  ren1_samp,
    input  wen0_samp,
    input  wen1_samp,
    input  [LOGDWORDS-1:0] addr0_samp,
    input  [LOGDWORDS-1:0] addr1_samp,
    input  [31:0] din0_samp,
    input  [31:0] din1_samp,
    output [31:0] dout0_samp,
    output [31:0] dout1_samp,
    // Computation 
    input  wen0,
    input  wen1,
    input  ren0,
    input  ren1,
    input  [LOGSWORDS-1:0] addr0,
    input  [LOGSWORDS-1:0] addr1,
    input  [B_WIDTH-1:0] din0,
    input  [B_WIDTH-1:0] din1,
    output [B_WIDTH-1:0] dout0,
    output [B_WIDTH-1:0] dout1
);


    
    // Signals ///////////////////////////////////////////////////////////////////
    wire ren_bram0, ren_bram1;
    wire wren_a, wren_b;
    wire [ 9:0] addr_a, addr_b;
    wire [31:0] din_a, din_b;
    wire [31:0] dout_a, dout_b;



    // Description ///////////////////////////////////////////////////////////////
    // reading
    assign ren_bram0 = sampling ? ren0_samp : ren0;
    assign ren_bram1 = sampling ? ren1_samp : ren1;
    
    // writing
    assign wren_a = sampling ? wen0_samp : wen0;
    assign wren_b = sampling ? wen1_samp : wen1;

    // addresses
    generate if(LOGSWORDS >= 9) begin
        assign addr_a = sampling ? {1'b0, addr0_samp} : {1'b0, addr0};
        assign addr_b = sampling ? {1'b1, addr1_samp} : {1'b1, addr1};
    end else begin
        assign addr_a = sampling ? {1'b0, {10-(LOGDWORDS+1){1'b0}} , addr0_samp} : {1'b0, {10-(LOGSWORDS+1){1'b0}} , addr0};
        assign addr_b = sampling ? {1'b1, {10-(LOGDWORDS+1){1'b0}} , addr1_samp} : {1'b1, {10-(LOGSWORDS+1){1'b0}} , addr1};
    end endgenerate
    
    // inputs
    assign din_a = sampling == 1'b1 ? din0_samp : din0;
    assign din_b = sampling == 1'b1 ? din1_samp : din1;
    //assign dout1_samp = dout_b;
    
    // outputs
    assign dout0_samp = dout_a;
    assign dout1_samp = dout_b;
    
    assign dout0 = dout_a;
    assign dout1 = dout_b;
    
    
    // BRAM Instantiation ////////////////////////////////////////////////////////
    BIKE_bram_dual_port BRAM(
        // control ports
        .clk(clk),
        .resetn(resetn),
        .wen_a(wren_a),
        .wen_b(wren_b),
        .ren_a(ren_bram0),
        .ren_b(ren_bram1),
        // I/O
        .addr_a(addr_a),
        .addr_b(addr_b),
        .dout_a(dout_a),
        .dout_b(dout_b),
        .din_a(din_a),
        .din_b(din_b)        
    );
    //////////////////////////////////////////////////////////////////////////////
    
endmodule
