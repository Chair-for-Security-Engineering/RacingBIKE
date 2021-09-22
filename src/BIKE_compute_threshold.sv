`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         2021-05-10
// Module Name:         BIKE_compute_threshold
// Description:         Computes the threshold used in the decoder.
// 
// Dependencies:        None.
// 
// Revision:        
// Revision             0.01 - File Created
// Usage Information:   Please look at readme.txt. If licence.txt or readme.txt
//						are missing or if you have questions regarding the code						
//						please contact Jan Richter-Brockmann (jan.richter-brockmann@rub.de)
//
//                      THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY 
//                      KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//                      IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
//                      PARTICULAR PURPOSE.
//
//////////////////////////////////////////////////////////////////////////////////




import BIKE_PACKAGE::*;

module BIKE_compute_threshold(
        input  wire clk,
        input  wire enable,
        input  wire [LOGRBITS-1:0] s,
        output wire [int'($clog2(W/2))-1:0] t
    );
    
    
    
    // Wires and registers
    wire [24:0] a;
    wire [17:0] b;
    wire [47:0] c;
    wire [47:0] dout;
    wire [int'($clog2(W/2))-1:0] res_muladd;
    
    
    // Threshold
    assign a = TH_F;
    assign b = {{(18-LOGRBITS){1'b0}}, s};
    assign c = TH_T;
    
    BIKE_mul_add muladd(
        .clk(clk),
        .enable(enable),
        .resetn(1'b1),
        .din_a(a),
        .din_b(b),
        .din_c(c),
        .dout(dout)
    );
    
    assign res_muladd = dout[int'($clog2(W/2))-1+31:31];
    
    assign t = (res_muladd > MAX_C) ? res_muladd : MAX_C;
       
endmodule
