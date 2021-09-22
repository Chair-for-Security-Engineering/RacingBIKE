//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         21.09.2021 
// Module Name:         BIKE_BRAM_DUAL_PORT
// Description:         Describes a dual port memory.
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
// Further details:     https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/ug/ug-qpp-design-recommendations.pdf
//
//////////////////////////////////////////////////////////////////////////////////


module BIKE_bram_dual_port(
    // Control Ports
    input  clk,
    input  resetn, 
    input  wen_a, wen_b,
    input  ren_a, ren_b,
    // I/O
    input  [ 9:0] addr_a, 
    input  [ 9:0] addr_b,
    output reg [31:0] dout_a,
    output reg [31:0] dout_b,
    input  [31:0] din_a,
    input  [31:0] din_b
);
    
    
    
    // Register and Signals //////////////////////////////////////////////////////
    reg [31:0] memory [2**10-1:0];
    
    initial begin
        for(integer i=0; i<2**10; i=i+1) memory[i] = 32'b0;
    end
    
    
    
    // Description ///////////////////////////////////////////////////////////////
    
//    always @(posedge clk) begin
//        if(~resetn) begin
//            dout_a <= 'b0;
//        end
//        else begin
//            if(ren_a) begin
//                if (wen_a) begin
//                    memory[addr_a] <= din_a;
//                end
//                dout_a <= memory[addr_a];
//            end 
//        end
//    end

//    // Port B
//    always @(posedge clk) begin
//        if(~resetn) begin
//            dout_b <= 'b0;
//        end
//        else begin
//            if(ren_b) begin
//                if (wen_b) begin
//                    memory[addr_b] <= din_b;
//                end
//                dout_b <= memory[addr_b];
//            end 
//        end
//    end  
    
    // without read first option /////////////////////////////////////////////////
    // Port A
//    always @(posedge clk) begin
//        if(ren_a) begin
//            if (wen_a) begin
//                memory[addr_a] = din_a;
//            end
//            dout_a = memory[addr_a];
//        end else begin
//            dout_a = 'b0;
//        end
//    end

//    // Port B
//    always @(posedge clk) begin
//        if(ren_b) begin
//            if (wen_b) begin
//                memory[addr_b] = din_b;
//            end
//            dout_b = memory[addr_b];
//        end else begin
//            dout_b = 'b0;
//        end
//    end  
    //////////////////////////////////////////////////////////////////////////////
    
    
    // with read first option ////////////////////////////////////////////////////
    // Port A
    always @(posedge clk) begin
        if (ren_a) begin
            dout_a <= memory[addr_a];
            if (wen_a) begin
                memory[addr_a] = din_a;
            end 
        end else begin
            dout_a <= 32'b0;
        end
    end

    // Port B
    always @(posedge clk) begin
        if (ren_b) begin
            dout_b <= memory[addr_b];
            if (wen_b) begin
                memory[addr_b] = din_b;
            end 
        end else begin
            dout_b <= 32'b0;
        end
    end
    //////////////////////////////////////////////////////////////////////////////
    
endmodule
