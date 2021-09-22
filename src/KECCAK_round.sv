//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.01.2021 
// Module Name:         KECCAK_ROUND
// Description:         Five steps of a KECCAK round.
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

import KECCAK_PACKAGE::*;

module KECCAK_round(
    input  [LANE_WIDTH-1:0] state_in  [4:0][4:0],
    output [LANE_WIDTH-1:0] state_out [4:0][4:0],
    input  [CNT_LENGTH_ROUND-1:0] round_number
);



// Wires and registers ///////////////////////////////////////////////////////////
wire [LANE_WIDTH-1:0] theta_in  [4:0][4:0];
wire [LANE_WIDTH-1:0] theta_out [4:0][4:0];
wire [LANE_WIDTH-1:0] roh_in    [4:0][4:0];
wire [LANE_WIDTH-1:0] roh_out   [4:0][4:0];
wire [LANE_WIDTH-1:0] pi_in     [4:0][4:0];
wire [LANE_WIDTH-1:0] pi_out    [4:0][4:0];
wire [LANE_WIDTH-1:0] chi_in    [4:0][4:0];
wire [LANE_WIDTH-1:0] chi_out   [4:0][4:0];
wire [LANE_WIDTH-1:0] iota_in   [4:0][4:0];
wire [LANE_WIDTH-1:0] iota_out  [4:0][4:0];

wire [LANE_WIDTH-1:0] theta_int1 [4:0];
wire [LANE_WIDTH-1:0] theta_int2 [4:0];

wire [LANE_WIDTH-1:0] keccak_roundconst;

//integer idx0 = 0;



// Description ///////////////////////////////////////////////////////////////////
    assign theta_in = state_in;
    
    // theta step
    generate 
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                assign theta_int1[x][z] = theta_in[x][0][z] ^ theta_in[x][1][z] ^ theta_in[x][2][z] ^ theta_in[x][3][z] ^ theta_in[x][4][z];
            end
        end 
    endgenerate

    generate 
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                assign theta_int2[x][z] = theta_int1[my_mod(int'(int'(x)-1), 5)][z] ^ theta_int1[my_mod(int'(int'(x)+1), 5)][my_mod(int'(int'(z)-1), LANE_WIDTH)];
                //assign theta_int2[x][z] = theta_int1[(int'(int'(x)-1) % 5)][z] ^ theta_int1[(int'(int'(x)+1) % 5)][(int'(int'(z)-1) % LANE_WIDTH)];
            end
        end 
    endgenerate
    
    generate
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar y=0; y<5; y=y+1) begin
                for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                    assign theta_out[x][y][z] = theta_in[x][y][z] ^ theta_int2[x][z];
                end    
            end
        end
    endgenerate
    
    assign roh_in = theta_out;
    
    
    // roh step
    generate
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar y=0; y<5; y=y+1) begin
                for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                    //assign roh_out[x][y][z] = roh_in[x][y][(int'(z)-rohindex[y][x]) % LANE_WIDTH];
                    assign roh_out[x][y][z] = roh_in[x][y][my_mod((int'(z)-rohindex[y][x]), LANE_WIDTH)];
                end    
            end
        end
    endgenerate
    
    assign pi_in = roh_out;
    
    
    // pi step
    generate
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar y=0; y<5; y=y+1) begin
                for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                    //assign pi_out[y][(2*x+3*y) % 5][z] = pi_in[x][y][z];
                    assign pi_out[y][my_mod((2*x+3*y), 5)][z] = pi_in[x][y][z];
                end    
            end
        end
    endgenerate    
    
    assign chi_in = pi_out;
    
    
    // chi step
    generate
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar y=0; y<5; y=y+1) begin
                for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                    //assign chi_out[x][y][z] = chi_in[x][y][z] ^ ((~chi_in[(x+1)%5][y][z]) & chi_in[(x+2)%5][y][z]);
                    assign chi_out[x][y][z] = chi_in[x][y][z] ^ ((~chi_in[my_mod((x+1), 5)][y][z]) & chi_in[my_mod((x+2), 5)][y][z]);
                end    
            end
        end
    endgenerate
    
    assign iota_in = chi_out;
    
    
    // iota step
    generate
        for(genvar x=0; x<5; x=x+1) begin
            for(genvar y=0; y<5; y=y+1) begin
                for(genvar z=0; z<LANE_WIDTH; z=z+1) begin
                    if(x==0 & y==0) begin
                        assign iota_out[x][y][z] = iota_in[x][y][z] ^ keccak_roundconst[z];
                    end 
                    else begin
                        assign iota_out[x][y][z] = iota_in[x][y][z];
                    end
                end    
            end
        end
    endgenerate
    
    assign state_out = iota_out;
    
    
    // Round constants
    KECCAK_RC keccak_rc(.round(round_number), .const_out(keccak_roundconst));
    
//////////////////////////////////////////////////////////////////////////////////
endmodule
