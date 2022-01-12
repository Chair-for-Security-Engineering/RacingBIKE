//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         21.09.2021 
// Module Name:         RegisterFDRE
// Description:         Just a simple (and scalable) register.
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

module RegisterFDRE
    #(
        parameter SIZE = 8
    )(
        input  clk,
        input  resetn,
        input  enable,
        // data
        input  [SIZE-1:0] d,
        output reg [SIZE-1:0] q
    );

    // Register description //////////////////////////////////////////////////////
    always @ (posedge clk) begin
        if(~resetn) begin
            q <= {SIZE{1'b0}};
        end
        else begin
            if (enable) begin
                q <= d;
            end
            else begin
                q <= q;
            end
        end
    end        
    //////////////////////////////////////////////////////////////////////////////
    
endmodule
