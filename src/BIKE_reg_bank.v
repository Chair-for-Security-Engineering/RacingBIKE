`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         21.09.2021 
// Module Name:         BIKE_REG_BANK
// Description:         Register bank.
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


module BIKE_reg_bank
    #(
        parameter SIZE = 8
    )(
        input  clk,
        input  resetn, 
        input  [SIZE-1:0] enable,
        input  [31:0] din,
        output [SIZE*32-1:0] dout
);
       
    // -- Description ------------------------------------------------------------
    generate for(genvar i=0; i < SIZE; i=i+1) begin
        RegisterFDRE #(.SIZE(32)) r0 (clk, resetn, enable[i], din, dout[i*32+31:i*32]);
    end endgenerate
    
endmodule
