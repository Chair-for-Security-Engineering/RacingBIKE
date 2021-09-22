`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         21.09.2021 
// Module Name:         BIKE_BRAM
// Description:         Top Level of the generic memory used in BIKE.
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
module BIKE_BRAM(
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



    // Description ///////////////////////////////////////////////////////////////
    generate if (R_BITS <= BRAM_CAP/2 && B_WIDTH == 32) begin
        BIKE_GENERIC_BRAM_SHARED BRAM_single_inst(
            .clk(clk),
            .resetn(resetn),
            .sampling(sampling),
            // Sampling
            .ren0_samp(ren0_samp),
            .ren1_samp(ren1_samp),
            .wen0_samp(wen0_samp),
            .wen1_samp(wen1_samp),
            .addr0_samp(addr0_samp),
            .addr1_samp(addr1_samp),
            .din0_samp(din0_samp),
            .din1_samp(din1_samp),
            .dout0_samp(dout0_samp),
            .dout1_samp(dout1_samp),
            // Computation
            .wen0(wen0),
            .wen1(wen1),
            .ren0(ren0),
            .ren1(ren1),
            .addr0(addr0),
            .addr1(addr1),
            .din0(din0),
            .din1(din1),
            .dout0(dout0),
            .dout1(dout1)
        );
    end else begin
        BIKE_generic_bram BRAM_DUAL0(
            .clk(clk),
            .resetn(resetn),
            .sampling(sampling),
            // Sampling
            .wen_samp(wen0_samp),
            .ren_samp(ren0_samp),
            .addr_samp(addr0_samp),
            .din_samp(din0_samp),
            .dout_samp(dout0_samp),
            // Computation
            .wen(wen0),
            .ren(ren0),
            .addr(addr0),
            .din(din0),
            .dout(dout0)
        );
        
        BIKE_generic_bram BRAM_DUAL1(
            .clk(clk),
            .resetn(resetn),
            .sampling(sampling),
            // Sampling
            .wen_samp(wen1_samp),
            .ren_samp(ren1_samp),
            .addr_samp(addr1_samp),
            .din_samp(din1_samp),
            .dout_samp(dout1_samp),
            // Computation
            .wen(wen1),
            .ren(ren1),
            .addr(addr1),
            .din(din1),
            .dout(dout1)
        );
    end endgenerate
    //////////////////////////////////////////////////////////////////////////////
    
endmodule
