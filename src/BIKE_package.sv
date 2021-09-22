
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         2021-05-10
// Module Name:         BIKE_PACKAGE
// Description:         Package for BIKE.
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

package BIKE_PACKAGE;
    // -- PARAMETER --------------------------------------------------------------
    // BIKE Parameter
//    // Level-1 ///////////////////////////////////////////////////////////////////
//    parameter R_BITS        = 12323;
//    parameter T1            = 134;
//    parameter W             = 142;
//    parameter L             = 256;
//    // Threshold function max(TH_F*input+TH_T, MAX_C)
//    parameter TH_F          = 25'b0111001000111011100001101;
//    parameter TH_T          = 48'b000000000000011101000011110101110000101000111101;
//    parameter MAX_C         = 36;
//
//    // Decoder
//    parameter TAU           = 3;
//    parameter NBITER        = 5+2;
//    //////////////////////////////////////////////////////////////////////////////

//    // Level-3 ///////////////////////////////////////////////////////////////////
//    parameter R_BITS        = 24659;
//    parameter T1            = 199;
//    parameter W             = 206;
//    parameter L             = 256;
    
//    // Threshold function max(TH_F*input+TH_T, MAX_C)
//    parameter TH_F          = 25'b0101011001000011000000101;
//    parameter TH_T          = 48'b000000000000011110100001001000000101101111000000;
//    parameter MAX_C         = 52;
    
//    // Decoder
//    parameter TAU           = 3;
//    parameter NBITER        = 5+2;
//    //////////////////////////////////////////////////////////////////////////////

    // Level-5 ///////////////////////////////////////////////////////////////////
    parameter R_BITS        = 40973;
    parameter T1            = 264;
    parameter W             = 274;
    parameter L             = 256;
    
    // Threshold function max(TH_F*input+TH_T, MAX_C)
    parameter TH_F          = 25'b0100000111101010001100000;
    parameter TH_T          = 48'b000000000000100101110000011100101011000000100000;
    parameter MAX_C         = 69;
    
    // Decoder
    parameter TAU           = 3;
    parameter NBITER        = 5+2;
    //////////////////////////////////////////////////////////////////////////////
    
    // Implementation parameters
    parameter B_WIDTH       = 32;
    parameter SWORDS        = int'(R_BITS/B_WIDTH)+1;
    parameter DWORDS        = int'(R_BITS/32)+1;
    parameter OVERHANG      = int'(R_BITS - B_WIDTH*(SWORDS-1));
    parameter N_BITS        = 2*R_BITS;
    parameter BRAM_CAP      = 32768;
    
    parameter LOGBWIDTH     = int'($clog2(int'(B_WIDTH)));
    parameter LOGRBITS      = int'($clog2(int'(R_BITS)));
    parameter LOGDWORDS     = int'($clog2(int'(DWORDS)));
    parameter LOGSWORDS     = int'($clog2(int'(SWORDS)));

    parameter INVERSION_STEPS = 23;
        
    
    // Functions
    function integer my_max (input integer x, input integer y);
        if(x >= y) begin
            my_max = x;
        end
        if(y > x) begin
            my_max = y;
        end
    endfunction : my_max

    function integer my_min (input integer x, input integer y);
        if(x <= y) begin
            my_min = x;
        end
        else begin
            my_min = y;
        end
    endfunction : my_min
    
    function integer div_and_ceil(input integer x, input integer y);
        div_and_ceil = 1;
        while (x > y) begin
            x = x - y;
            div_and_ceil = div_and_ceil + 1;
        end
    endfunction : div_and_ceil;

    function integer div_and_floor(input integer x, input integer y);
        div_and_floor = 0;
        while (x >= y) begin
            x = x - y;
            div_and_floor = div_and_floor + 1;
        end
    endfunction : div_and_floor;

endpackage
