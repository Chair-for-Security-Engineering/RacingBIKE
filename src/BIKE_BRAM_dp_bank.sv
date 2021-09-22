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
module BIKE_BRAM_dp_bank
    #(
        parameter SIZE = 4
    )(
        input  clk,
        input  resetn,
        input  sampling [SIZE-1:0],
        // Sampling
        input  ren0_samp [SIZE-1:0],
        input  ren1_samp [SIZE-1:0],
        input  wen0_samp [SIZE-1:0],
        input  wen1_samp [SIZE-1:0],
        input  [LOGDWORDS-1:0] addr0_samp [SIZE-1:0],
        input  [LOGDWORDS-1:0] addr1_samp [SIZE-1:0],
        input  [31:0] din0_samp [SIZE-1:0],
        input  [31:0] din1_samp [SIZE-1:0],
        output [31:0] dout0_samp [SIZE-1:0],
        output [31:0] dout1_samp [SIZE-1:0],
        // Computation
        input  wen0 [SIZE-1:0],
        input  wen1 [SIZE-1:0],
        input  ren0 [SIZE-1:0],
        input  ren1 [SIZE-1:0],
        input  [LOGSWORDS-1:0] addr0 [SIZE-1:0],
        input  [LOGSWORDS-1:0] addr1 [SIZE-1:0],
        input  [B_WIDTH-1:0] din0 [SIZE-1:0],
        input  [B_WIDTH-1:0] din1 [SIZE-1:0],
        output [B_WIDTH-1:0] dout0 [SIZE-1:0],
        output [B_WIDTH-1:0] dout1 [SIZE-1:0]
    );
    
    
    
    // Description ///////////////////////////////////////////////////////////////
    generate for(genvar i=0; i < SIZE; i=i+1) begin
        BIKE_BRAM BRAM(
            .clk(clk),
            .resetn(resetn),
            .sampling(sampling[i]),
            // Sampling
            .ren0_samp(ren0_samp[i]),
            .ren1_samp(ren1_samp[i]),
            .wen0_samp(wen0_samp[i]),
            .wen1_samp(wen1_samp[i]),
            .addr0_samp(addr0_samp[i]),
            .addr1_samp(addr1_samp[i]),
            .din0_samp(din0_samp[i]),
            .din1_samp(din1_samp[i]),
            .dout0_samp(dout0_samp[i]),
            .dout1_samp(dout1_samp[i]),
            // Computation
            .wen0(wen0[i]),
            .wen1(wen1[i]),
            .ren0(ren0[i]),
            .ren1(ren1[i]),
            .addr0(addr0[i]),
            .addr1(addr1[i]),
            .din0(din0[i]),
            .din1(din1[i]),
            .dout0(dout0[i]),
            .dout1(dout1[i])
        );
    end endgenerate
    //////////////////////////////////////////////////////////////////////////////
    
endmodule
