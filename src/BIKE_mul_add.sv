`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         22.02.2021 
// Module Name:         BIKE_mul_add
// Description:         Multiply and add using DSP.
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


module BIKE_mul_add(
    input clk,
    input enable,
    input resetn,
    // Data ports
    input [24:0] din_a,
    input [17:0] din_b,
    input [47:0] din_c,
    output [47:0] dout
);



// Wires and registers
wire [29:0] a;



// Description
assign a = {5'b00000, din_a};


// DSP48E1: 48-bit Multi-Functional Arithmetic Block
//          7 Series
// Xilinx HDL Language Template, version 2020.1_versal_lib
DSP48E1 #(
   // Feature Control Attributes: Data Path Selection
   .A_INPUT("DIRECT"),               // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
   .B_INPUT("DIRECT"),               // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
   .USE_DPORT("FALSE"),              // Select D port usage (TRUE or FALSE)
   .USE_MULT("MULTIPLY"),            // Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
   .USE_SIMD("ONE48"),               // SIMD selection ("ONE48", "TWO24", "FOUR12")
   // Pattern Detector Attributes: Pattern Detection Configuration
   .AUTORESET_PATDET("NO_RESET"),    // "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
   .MASK(48'h3fffffffffff),          // 48-bit mask value for pattern detect (1=ignore)
   .PATTERN(48'h000000000000),       // 48-bit pattern match for pattern detect
   .SEL_MASK("MASK"),                // "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
   .SEL_PATTERN("PATTERN"),          // Select pattern value ("PATTERN" or "C")
   .USE_PATTERN_DETECT("NO_PATDET"), // Enable pattern detect ("PATDET" or "NO_PATDET")
   // Register Control Attributes: Pipeline Register Configuration
   .ACASCREG(0),                     // Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
   .ADREG(0),                        // Number of pipeline stages for pre-adder (0 or 1)
   .ALUMODEREG(0),                   // Number of pipeline stages for ALUMODE (0 or 1)
   .AREG(0),                         // Number of pipeline stages for A (0, 1 or 2)
   .BCASCREG(0),                     // Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
   .BREG(0),                         // Number of pipeline stages for B (0, 1 or 2)
   .CARRYINREG(0),                   // Number of pipeline stages for CARRYIN (0 or 1)
   .CARRYINSELREG(0),                // Number of pipeline stages for CARRYINSEL (0 or 1)
   .CREG(0),                         // Number of pipeline stages for C (0 or 1)
   .DREG(0),                         // Number of pipeline stages for D (0 or 1)
   .INMODEREG(0),                    // Number of pipeline stages for INMODE (0 or 1)
   .MREG(0),                         // Number of multiplier pipeline stages (0 or 1)
   .OPMODEREG(0),                    // Number of pipeline stages for OPMODE (0 or 1)
   .PREG(1)                          // Number of pipeline stages for P (0 or 1)
)
DSP48E1_inst (
   // Cascade: 30-bit (each) output: Cascade Ports
   .ACOUT(),                   // 30-bit output: A port cascade output
   .BCOUT(),                   // 18-bit output: B port cascade output
   .CARRYCASCOUT(),     // 1-bit output: Cascade carry output
   .MULTSIGNOUT(),       // 1-bit output: Multiplier sign cascade output
   .PCOUT(),                   // 48-bit output: Cascade output
   // Control: 1-bit (each) output: Control Inputs/Status Bits
   .OVERFLOW(),             // 1-bit output: Overflow in add/acc output
   .PATTERNBDETECT(), // 1-bit output: Pattern bar detect output
   .PATTERNDETECT(),   // 1-bit output: Pattern detect output
   .UNDERFLOW(),           // 1-bit output: Underflow in add/acc output
   // Data: 4-bit (each) output: Data Ports
   .CARRYOUT(),             // 4-bit output: Carry output
   .P(dout),                           // 48-bit output: Primary data output
   // Cascade: 30-bit (each) input: Cascade Ports
   .ACIN(30'b0),                     // 30-bit input: A cascade data input
   .BCIN(18'b0),                     // 18-bit input: B cascade input
   .CARRYCASCIN(1'b0),       // 1-bit input: Cascade carry input
   .MULTSIGNIN(1'b0),         // 1-bit input: Multiplier sign input
   .PCIN(48'b0),                     // 48-bit input: P cascade input
   // Control: 4-bit (each) input: Control Inputs/Status Bits
   .ALUMODE(4'b0),               // 4-bit input: ALU control input
   .CARRYINSEL(3'b0),         // 3-bit input: Carry select input
   .CLK(clk),                       // 1-bit input: Clock input
   .INMODE(5'b0),                 // 5-bit input: INMODE control input
   .OPMODE(7'b0110101),                 // 7-bit input: Operation mode input
   // Data: 30-bit (each) input: Data Ports
   .A(a),                           // 30-bit input: A data input
   .B(din_b),                           // 18-bit input: B data input
   .C(din_c),                           // 48-bit input: C data input
   .CARRYIN(1'b0),               // 1-bit input: Carry input signal
   .D(25'b0),                           // 25-bit input: D data input
   // Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
   .CEA1(1'b0),                     // 1-bit input: Clock enable input for 1st stage AREG
   .CEA2(1'b0),                     // 1-bit input: Clock enable input for 2nd stage AREG
   .CEAD(1'b0),                     // 1-bit input: Clock enable input for ADREG
   .CEALUMODE(1'b0),           // 1-bit input: Clock enable input for ALUMODE
   .CEB1(1'b0),                     // 1-bit input: Clock enable input for 1st stage BREG
   .CEB2(1'b0),                     // 1-bit input: Clock enable input for 2nd stage BREG
   .CEC(1'b0),                       // 1-bit input: Clock enable input for CREG
   .CECARRYIN(1'b0),           // 1-bit input: Clock enable input for CARRYINREG
   .CECTRL(1'b0),                 // 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
   .CED(1'b0),                       // 1-bit input: Clock enable input for DREG
   .CEINMODE(1'b0),             // 1-bit input: Clock enable input for INMODEREG
   .CEM(1'b0),                       // 1-bit input: Clock enable input for MREG
   .CEP(enable),                       // 1-bit input: Clock enable input for PREG
   .RSTA(1'b0),                     // 1-bit input: Reset input for AREG
   .RSTALLCARRYIN(1'b0),   // 1-bit input: Reset input for CARRYINREG
   .RSTALUMODE(1'b0),         // 1-bit input: Reset input for ALUMODEREG
   .RSTB(1'b0),                     // 1-bit input: Reset input for BREG
   .RSTC(1'b0),                     // 1-bit input: Reset input for CREG
   .RSTCTRL(1'b0),               // 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
   .RSTD(1'b0),                     // 1-bit input: Reset input for DREG and ADREG
   .RSTINMODE(1'b0),           // 1-bit input: Reset input for INMODEREG
   .RSTM(1'b0),                     // 1-bit input: Reset input for MREG
   .RSTP(~resetn)                      // 1-bit input: Reset input for PREG
);
// End of DSP48E1_inst instantiation

endmodule
