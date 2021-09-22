//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         11.01.2021 
// Module Name:         KECCAK_PACKAGE
// Description:         Package for KECCAK.
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


package KECCAK_PACKAGE;
    // -- PARAMETER --------------------------------------------------------------
    parameter STATE_WIDTH           = 1600;
    parameter RATE                  = 1344;
    parameter N_R                   = 24;
    parameter D                     = 384;
    
    // internally used parameters
    parameter integer LANE_WIDTH    = int'(STATE_WIDTH/25);
    parameter ABSORBING_PHASES      = 1;
    parameter SEED_LANES            = int'(RATE/LANE_WIDTH);
    
    parameter CNT_LENGTH_ROUND      = int'($clog2(N_R+1));
    
    parameter integer rohindex [0:4][0:4] = '{'{0, 1, 62, 28, 27}, '{36, 44, 6, 55, 20}, '{3, 10, 43, 25, 39}, '{41, 45, 15, 21, 8}, '{18, 2, 61, 56, 14}};
    
    
    function integer my_mod (input integer x, input integer m);
        if(x < 0) begin
            my_mod = x+m;
            while(my_mod < 0) begin
                my_mod = my_mod+m;
            end
        end else if(x >= m) begin
            my_mod = x-m;
            while(my_mod >= m) begin
                my_mod = my_mod-m;
            end
        end else begin
            my_mod = x;
        end
    endfunction

endpackage
