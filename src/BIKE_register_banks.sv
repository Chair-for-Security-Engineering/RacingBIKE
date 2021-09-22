//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         04.01.2021 
// Module Name:         BIKE_register_banks
// Description:         Wrapper for register banks required to store 256 bit values.
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


module BIKE_register_banks
    #(
        parameter NUM_OF_BANKS = 4,
        parameter BANK_SIZE = 8
    )(
        input  clk,
        input  resetn [NUM_OF_BANKS-1:0],
        input  [BANK_SIZE-1:0] enable [NUM_OF_BANKS-1:0],
        input  [31:0] din [NUM_OF_BANKS-1:0],
        output [BANK_SIZE*32-1:0] dout [NUM_OF_BANKS-1:0]
    );
    
    
    generate for(genvar i=0; i<NUM_OF_BANKS; i=i+1) begin
        BIKE_reg_bank #(.SIZE(BANK_SIZE)) reg_bank (.clk(clk), .resetn(resetn[i]), .enable(enable[i]), .din(din[i]), .dout(dout[i]));
    end endgenerate
    
endmodule
