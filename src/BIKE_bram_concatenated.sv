//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         08.04.2021 
// Module Name:         BIKE_bram_concatenated
// Description:         Concatenates c brams such that they can be accessed as one larger memory.
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


module BIKE_bram_concatenated #(
        parameter integer C = 2
    )(
        // Control Ports
        input  clk,
        input  resetn, 
        input  wen_a, wen_b,
        input  ren_a, ren_b,
        // I/O
        input  [ $clog2(C)+9:0] addr_a,
        input  [ $clog2(C)+9:0] addr_b,
        output reg [31:0] dout_a,
        output reg [31:0] dout_b,
        input  [31:0] din_a,
        input  [31:0] din_b
);
    
    
    
    // Register and Signals //////////////////////////////////////////////////////
    wire bram_wren_a [C-1:0];
    wire bram_wren_b [C-1:0];
    wire bram_rden_a [C-1:0];
    wire bram_rden_b [C-1:0];
    wire [ 9:0] bram_addr_a [C-1:0];
    wire [ 9:0] bram_addr_b [C-1:0];
    wire [31:0] bram_dout_a [C-1:0];
    wire [31:0] bram_dout_b [C-1:0];
    wire [31:0] bram_din_a [C-1:0];
    wire [31:0] bram_din_b [C-1:0];
    
    reg [$clog2(C)-1:0] msb_addr_a;
    reg [$clog2(C)-1:0] msb_addr_b;
    
    
    
    
    // Description ///////////////////////////////////////////////////////////////
    generate 
        if(C == 1) begin
            assign bram_wren_a[0] = wen_a;
            assign bram_wren_b[0] = wen_b;
            assign bram_rden_a[0] = ren_a;
            assign bram_rden_b[0] = ren_b;
            assign bram_addr_a[0] = addr_a;
            assign bram_addr_b[0] = addr_b;
            assign bram_din_a[0]  = din_a;
            assign bram_din_b[0]  = din_b;
            assign dout_a = bram_dout_a[0];
            assign dout_b = bram_dout_b[0];
        end
        else begin
            for(genvar i=0; i<C; i=i+1) begin
                assign bram_rden_a[i] = (ren_a && (addr_a[$clog2(C)+9:9+1] == i)) ? 1'b1 : 1'b0; 
                assign bram_rden_b[i] = (ren_b && (addr_b[$clog2(C)+9:9+1] == i)) ? 1'b1 : 1'b0; 
                assign bram_wren_a[i] = (wen_a && (addr_a[$clog2(C)+9:9+1] == i)) ? 1'b1 : 1'b0; 
                assign bram_wren_b[i] = (wen_b && (addr_b[$clog2(C)+9:9+1] == i)) ? 1'b1 : 1'b0; 
                
                assign bram_addr_a[i] = addr_a[9:0];
                assign bram_addr_b[i] = addr_b[9:0];
                
                assign bram_din_a[i] = din_a;
                assign bram_din_b[i] = din_b;
            end
            
            always @ (posedge clk or negedge resetn) begin
                if(~resetn) begin
                    msb_addr_a <= 'b0;
                    msb_addr_b <= 'b0;
                end
                else begin
                    msb_addr_a <= addr_a[$clog2(C)+9:9+1];            
                    msb_addr_b <= addr_b[$clog2(C)+9:9+1];            
                end
            end
            
            assign dout_a = bram_dout_a[msb_addr_a];        
            assign dout_b = bram_dout_b[msb_addr_b];        
        end        
    endgenerate    
    
    
    // Memory instantiations
    generate
        for(genvar i=0; i<C; i=i+1) begin
            BIKE_bram_dual_port BRAM_inst (
                .clk(clk),
                // Control Ports
                .resetn(resetn),
                .wen_a(bram_wren_a[i]),
                .wen_b(bram_wren_b[i]),
                .ren_a(bram_rden_a[i]),
                .ren_b(bram_rden_b[i]),
                // I/O
                .addr_a(bram_addr_a[i]),
                .addr_b(bram_addr_b[i]),
                .dout_a(bram_dout_a[i]),
                .dout_b(bram_dout_b[i]),
                .din_a(bram_din_a[i]),
                .din_b(bram_din_b[i])   
            );
        end
    endgenerate
    /////////////////////////////////////////////////////////////////////////////
    
endmodule
