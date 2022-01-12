`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         08.04.2021 
// Module Name:         BIKE_generic_bram
// Description:         Wrapper for an generic memory interface.
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
//                      KIND, EITHER EXPRESSED OR IMPLIED, INCLUdinG BUT NOT LIMITED TO THE
//                      IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
//                      PARTICULAR PURPOSE.
//
//////////////////////////////////////////////////////////////////////////////////



// Imports
import BIKE_PACKAGE::*;



module BIKE_generic_bram(
    input wire clk,
    input wire resetn,
    input wire sampling,
    input wire wen_samp,
    input wire ren_samp,
    input wire [LOGDWORDS-1:0] addr_samp,
    output reg [31:0] dout_samp,
    input wire [31:0] din_samp,
    input wire wen,
    input wire ren,
    input wire [LOGSWORDS-1:0] addr,
    output reg [B_WIDTH-1:0] dout,
    input wire [B_WIDTH-1:0] din
);



// PARAMETERS ////////////////////////////////////////////////////////////////////
parameter integer PAR               = div_and_ceil(B_WIDTH, 64);
parameter integer C                 = div_and_ceil(R_BITS, PAR*BRAM_CAP);
parameter integer BRAM_ADDR_WIDTH   = 10+$clog2(C);
parameter integer LOGPAR            = $clog2(PAR);





// SIGNALS ///////////////////////////////////////////////////////////////////////
wire bram_wren_a [PAR-1:0];
wire bram_wren_b [PAR-1:0];
wire bram_rden_a [PAR-1:0];
wire bram_rden_b [PAR-1:0];
wire [BRAM_ADDR_WIDTH-1:0] bram_addr_a [PAR-1:0];
wire [BRAM_ADDR_WIDTH-1:0] bram_addr_b [PAR-1:0];
wire [31:0] bram_din_a [PAR-1:0];
wire [31:0] bram_din_b [PAR-1:0];
wire [31:0] bram_dout_a [PAR-1:0];
wire [31:0] bram_dout_b [PAR-1:0];

wire samp_wren [PAR-1:0];
wire samp_rden [PAR-1:0];
wire [BRAM_ADDR_WIDTH-1:0] samp_addr [PAR-1:0];
wire [31:0] samp_din [PAR-1:0];

wire scale_wren_a [PAR-1:0];
wire scale_wren_b [PAR-1:0];
wire scale_rden_a [PAR-1:0];
wire scale_rden_b [PAR-1:0];
wire [BRAM_ADDR_WIDTH-1:0] scale_addr_a [PAR-1:0];
wire [BRAM_ADDR_WIDTH-1:0] scale_addr_b [PAR-1:0];
wire [31:0] scale_din_a [PAR-1:0];
wire [31:0] scale_din_b [PAR-1:0];

reg [$clog2(PAR)-1:0] lsb_samp_addr;


// DESCRIPTION ///////////////////////////////////////////////////////////////////

generate
    if(PAR == 1) begin
        assign bram_wren_a[0] = (sampling == 1'b1) ? wen_samp : scale_wren_a[0];
        assign bram_wren_b[0] = (sampling == 1'b1) ? 1'b0 : scale_wren_b[0];
        assign bram_rden_a[0] = (sampling == 1'b1) ? ren_samp : scale_rden_a[0];
        assign bram_rden_b[0] = (sampling == 1'b1) ? 1'b0 : scale_rden_b[0];
        assign bram_addr_a[0] = (sampling == 1'b1) ? {{BRAM_ADDR_WIDTH-LOGDWORDS{1'b0}}, addr_samp} : scale_addr_a[0];
        assign bram_addr_b[0] = (sampling == 1'b1) ? {BRAM_ADDR_WIDTH{1'b0}} : scale_addr_b[0];
        assign bram_din_a[0]  = (sampling == 1'b1) ? din_samp : scale_din_a[0];
        assign bram_din_b[0]  = (sampling == 1'b1) ? 32'b0 : scale_din_b[0];
        
        assign dout_samp = (sampling == 1'b1) ? bram_dout_a[0] : 32'b0;
        
        // Scalable interface
        if(B_WIDTH == 32) begin
            assign scale_wren_a[0] = wen;
            assign scale_wren_b[0] = 1'b0;
            assign scale_rden_a[0] = ren;
            assign scale_rden_b[0] = 1'b0;
            assign scale_addr_a[0] = {{BRAM_ADDR_WIDTH-LOGSWORDS{1'b0}}, addr};
            assign scale_addr_b[0] = {BRAM_ADDR_WIDTH{1'b0}};
            assign scale_din_a[0]  = din; 
            assign scale_din_b[0]  = 32'b0;
            
            assign dout = (sampling == 1'b0) ? bram_dout_a[0] : 32'b0; 
        end
        else begin // i.e., B_WIDTH = 64
            assign scale_wren_a[0] = wen;
            assign scale_wren_b[0] = wen;
            assign scale_rden_a[0] = ren;
            assign scale_rden_b[0] = ren;
            assign scale_addr_a[0] = {{BRAM_ADDR_WIDTH-LOGSWORDS-1{1'b0}}, addr, 1'b0};
            assign scale_addr_b[0] = {{BRAM_ADDR_WIDTH-LOGSWORDS-1{1'b0}}, addr, 1'b1};
            assign scale_din_a[0]  = din[31:0]; 
            assign scale_din_b[0]  = din[63:32];
            
            assign dout = (sampling == 1'b0) ? {bram_dout_b[0], bram_dout_a[0]} : 64'b0; 
        end
    end
    else begin // B_WIDTH >= 128
        for(genvar i=0; i<PAR; i=i+1) begin
            assign bram_wren_a[i] = (sampling == 1'b1) ? samp_wren[i] : scale_wren_a[i];
            assign bram_wren_b[i] = (sampling == 1'b1) ? 1'b0 : scale_wren_b[i];
            assign bram_rden_a[i] = (sampling == 1'b1) ? samp_rden[i] : scale_rden_a[0];
            assign bram_rden_b[i] = (sampling == 1'b1) ? 1'b0 : scale_rden_b[i];
            assign bram_addr_a[i] = (sampling == 1'b1) ? samp_addr[i] : scale_addr_a[i];
            assign bram_addr_b[i] = (sampling == 1'b1) ? {BRAM_ADDR_WIDTH{1'b0}} : scale_addr_b[i];
            assign bram_din_a[i]  = (sampling == 1'b1) ? samp_din[i] : scale_din_a[i];
            assign bram_din_b[i]  = (sampling == 1'b1) ? 32'b0 : scale_din_b[i];
            
            assign samp_wren[i]   = (wen_samp == 1'b1 && addr_samp[LOGPAR:1] == i) ? 1'b1 : 1'b0;
            assign samp_rden[i]   = (ren_samp == 1'b1 && addr_samp[LOGPAR:1] == i) ? 1'b1 : 1'b0;
            if(BRAM_ADDR_WIDTH-LOGDWORDS+LOGPAR-1 < 0) begin
                assign samp_addr[i]   = {addr_samp[LOGDWORDS-1:LOGPAR+1], addr_samp[0]};
            end 
            else begin
                assign samp_addr[i]   = {{BRAM_ADDR_WIDTH-LOGDWORDS+LOGPAR-1{1'b0}}, addr_samp[LOGDWORDS-1:LOGPAR+1], addr_samp[0]};
            end            
            assign samp_din[i]    = din_samp;
        end
        
        assign dout_samp = bram_dout_a[lsb_samp_addr];
        
        always @(posedge clk) begin
            if(~resetn) begin
                lsb_samp_addr <= 'b0;
            end
            else begin
                lsb_samp_addr <= addr_samp[LOGPAR:1];
            end  
        end
        
        // Scalable interface
        for(genvar i=0; i<PAR; i=i+1) begin
            assign scale_wren_a[i] = wen;
            assign scale_wren_b[i] = wen;
            assign scale_rden_a[i] = ren;
            assign scale_rden_b[i] = ren;
            assign scale_addr_a[i] = {{BRAM_ADDR_WIDTH-LOGSWORDS-1{1'b0}}, addr, 1'b0};
            assign scale_addr_b[i] = {{BRAM_ADDR_WIDTH-LOGSWORDS-1{1'b0}}, addr, 1'b1};
            assign scale_din_a[i]  = din[i*64+31:i*64];
            assign scale_din_b[i]  = din[i*64+63:i*64+32];
            
            assign dout[i*64+31:i*64] = bram_dout_a[i];
            assign dout[i*64+63:i*64+32] = bram_dout_b[i];
        end
                          
    end
endgenerate



    
    
    
// BRAM INSTANTIATIONS ///////////////////////////////////////////////////////
generate 
    for (genvar p=0; p < PAR; p=p+1) begin: parallel_loop
        BIKE_bram_concatenated #(.C(C))
        BRAM_inst(
            .clk(clk),
            // Control Ports
            .resetn(resetn),
            .wen_a(bram_wren_a[p]),
            .wen_b(bram_wren_b[p]),
            .ren_a(bram_rden_a[p]),
            .ren_b(bram_rden_b[p]),
            // I/O
            .addr_a(bram_addr_a[p]),
            .addr_b(bram_addr_b[p]),
            .dout_a(bram_dout_a[p]),
            .dout_b(bram_dout_b[p]),
            .din_a(bram_din_a[p]),
            .din_b(bram_din_b[p])   
        );
    end 
endgenerate
////////////////////////////////////////////////////////////////////////////// 

endmodule
