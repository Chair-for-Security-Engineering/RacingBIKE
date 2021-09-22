`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Ruhr-University Bochum
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.05.2021 
// Module Name:         BIKE_COUNTER_DEC_INIT
// Description:         Decreasing counter with initial value.
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


module BIKE_counter_dec_init #(
        parameter SIZE = 5,
        parameter INIT = 1,
        parameter MAX_VALUE = 16
    )(
        input  clk,
        input  enable,
        input  resetn,
        output [SIZE-1:0] cnt_out
    );

    // wires and registers
    reg [SIZE-1:0] count;
    wire [SIZE-1:0] count_in;
    
    // counter process
    assign count_in = (count > 0) ? count-1 : MAX_VALUE[SIZE-1:0];
    
    always @ (posedge clk or negedge resetn) begin
        if(~resetn) begin
            count <= INIT[SIZE-1:0];
        end
        else if(enable) begin
            count <= count_in;
        end
    end
    
    // counter output
    assign cnt_out = count;

endmodule
