//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         15.02.2021 
// Module Name:         BIKE_hamming_weight
// Description:         Computes hamming weight.
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



module BIKE_hamming_weight (
    input  wire clk,
    input  wire enable,
    input  wire resetn,
    // Data ports
    input  wire [B_WIDTH-1:0] din,
    output wire [LOGRBITS-1:0] dout
);



// Wires and registers
wire [48*div_and_ceil(B_WIDTH, 48)-1:0] din_a [int'($clog2(B_WIDTH))-1:0];
wire [48*div_and_ceil(B_WIDTH, 48)-1:0] din_b [int'($clog2(B_WIDTH))-1:0];
wire [48*div_and_ceil(B_WIDTH, 48):0] add_out [int'($clog2(B_WIDTH)):0];
// wire [47:0] din_a [4:0];
// wire [47:0] din_b [4:0];
// wire [47:0] add_out [5:0];
wire [47:0] din_a_final;
wire [47:0] din_b_final;
wire [47:0] dout_final;



// Description

    // Hamming Weight ///////////////////////////////////////////////////////////
    // init vetor with input data
    assign add_out[0] = {{(48*div_and_ceil(B_WIDTH, 48)-B_WIDTH){1'b0}}, din};

    generate
        for(genvar t=0; t<int'($clog2(B_WIDTH)); t=t+1) begin
            // split data
            for(genvar i=0; i<int'(B_WIDTH/(2**(t+1))); i=i+1) begin
                assign din_a[t][i*(t+2)+t:i*(t+2)] = add_out[t][(t+1)*(i+1)-1:i*(t+1)];
                assign din_a[t][i*(t+2)+t+1]       = 1'b0;
                assign din_b[t][i*(t+2)+t:i*(t+2)] = add_out[t][(t+1)*(i+1)-1+int'(B_WIDTH/(2**t)*(t+1)/2):i*(t+1)+int'(B_WIDTH/(2**t)*(t+1)/2)];
                assign din_b[t][i*(t+2)+t+1]       = 1'b0;
            end

            // padding with zeros
            assign din_a[t][48*div_and_ceil(B_WIDTH, 48)-1:(t+2)*(B_WIDTH/2**(t+1))] = 'b0;
            assign din_b[t][48*div_and_ceil(B_WIDTH, 48)-1:(t+2)*(B_WIDTH/2**(t+1))] = 'b0;

            // DSPs
            for(genvar i=0; i<div_and_ceil(B_WIDTH/2**(t+1)*(t+2), 48); i=i+1) begin
                BIKE_add adder(
                    .clk(clk),
                    .enable(enable),
                    .resetn(resetn),
                    .din_a(din_a[t][48*(i+1)-1:48*i]),
                    .din_b(din_b[t][48*(i+1)-1:48*i]),
                    .dout(add_out[t+1][48*(i+1)-1:48*i])
                );
            end
        end
    endgenerate

    // final adder
    assign din_a_final = {{48-int'($clog2(B_WIDTH+1)){1'b0}}, add_out[int'($clog2(B_WIDTH))][int'($clog2(B_WIDTH+1))-1:0]};
    assign din_b_final = dout_final;

    BIKE_add adder_final(
            .clk(clk),
            .enable(enable),
            .resetn(resetn),
            .din_a(din_a_final),
            .din_b(din_b_final),
            .dout(dout_final)                
    );

    assign dout = dout_final[int'($clog2(R_BITS+1))-1:0];

endmodule
        
     