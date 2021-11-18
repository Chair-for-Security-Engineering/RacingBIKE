`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Chair for Security Engineering
// Engineer:            Jan Richter-Brockmann
// 
// Create Date:         22.09.2021 
// Module Name:         TB_BIKE
// Description:         Testbench.
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
import KECCAK_PACKAGE::*;


module TB_BIKE #(
        parameter file_id_output      = "test_output_file.txt",
        parameter file_id_c0          = "../../../../testvectors/r12323/c0.txt",
        parameter file_id_c1          = "../../../../testvectors/r12323/c1.txt",
        parameter file_id_e0          = "../../../../testvectors/r12323/e0.txt",
        parameter file_id_e1          = "../../../../testvectors/r12323/e1.txt",
        parameter file_id_h0          = "../../../../testvectors/r12323/h0.txt",
        parameter file_id_h1          = "../../../../testvectors/r12323/h1.txt",
        parameter file_id_h0_vec      = "../../../../testvectors/r12323/h0_vec.txt",
        parameter file_id_h1_vec      = "../../../../testvectors/r12323/h1_vec.txt",
        parameter file_id_pk          = "../../../../testvectors/r12323/pk.txt",
        parameter file_id_k           = "../../../../testvectors/r12323/k.txt",
        parameter file_id_m           = "../../../../testvectors/r12323/m.txt",
        parameter file_id_sigma       = "../../../../testvectors/r12323/sigma.txt",
        parameter file_id_sk_seed     = "../../../../testvectors/r12323/sk_seed.txt"
);
    
    // registers and wires
    reg  resetn;
    reg  start;
    reg  [2:0] instruction;
    wire busy, done;
    
    reg  rand_valid;
    wire rand_request;
    reg  [31:0] rand_din;
    
    wire din_ready;
    reg  [7:0] din_load;
    reg  [LOGDWORDS-1:0] din_addr;
    reg  [31:0] din;
    reg  din_done;
    
    reg  [6:0] request_data;            // Request data: 0000 0001: h_0, 0000 0010: h_1, 0000 0100: sigma, 0000 1000: h, 0001 0000: c_0, 0010 0000: c_1, 0100 0000: k
    reg  request_done;
    reg  dout_valid;
    reg  [LOGDWORDS-1:0] dout_addr;     // address of output data 
    reg  [31:0] dout;                   // output data is transferred in 32-bit chunks
    
    // definitions for tb
    reg [31:0] pk [DWORDS-1:0];
    reg [31:0] e0 [DWORDS-1:0];
    reg [31:0] e1 [DWORDS-1:0];
    reg [31:0] m  [7:0];
    
    reg [int'($clog2(R_BITS))-1:0] h0 [DWORDS-1:0];
    reg [int'($clog2(R_BITS))-1:0] h1 [DWORDS-1:0];
    reg [31:0] sigma [7:0];
    reg [31:0] sk_seed [7:0];
    
    reg [31:0] h0_vec [DWORDS-1:0];
    reg [31:0] h1_vec [DWORDS-1:0];
    reg [LOGRBITS:0] eprime [T1-1:0];
    reg [31:0] c0 [DWORDS-1:0];
    reg [31:0] c1 [7:0];
    
    reg [31:0] k [7:0];
    reg trigger;
    reg trigger2;
    
    // clock definition
    reg clk;
    localparam period = 10;
    localparam delta = 0.1;
    
    integer i = 0;
    int f_out;
    
    BIKE UUT (
        .clk(clk),
        // control ports
        .resetn(resetn),
        .start(start),
        .instruction(instruction),
        .busy(busy),
        .done(done),
        // randomness
        .rand_valid(rand_valid),
        .rand_request(rand_request),
        .rand_din(rand_din),
        // input data
        .din_ready(din_ready),
        .din_load(din_load),
        .din(din),
        .din_addr(din_addr),
        .din_done(din_done),
        // Output data
        .request_data(request_data),
        .request_done(request_done),
        .dout_valid(dout_valid),
        .dout_addr(dout_addr),
        .dout(dout)
    );
    
    // clock
    always begin
        clk = 1'b1;
        #(period/2);
        clk = 1'b0;
        #(period/2);
    end
    
    // stimulation
    initial begin
        f_out = $fopen(file_id_output, "w");
        $fdisplay(f_out, "Selected Parameters");
        $fdisplay(f_out, "R=%0d", R_BITS);
        $fdisplay(f_out, "T1=%0d", T1);
        $fdisplay(f_out, "W=%0d", W);
        $fdisplay(f_out, "LOG(R)=%0d", LOGRBITS);
        $fdisplay(f_out, "LOG(B_WIDTH)=%0d", LOGBWIDTH);
        $fdisplay(f_out, "Ranges %0d", int'(B_WIDTH/(2**1)*(1+1)/2));
        $fdisplay(f_out, "LSB %0d", SWORDS[0]);
      
        // initialize vectors for files
        for(integer i=0; i<DWORDS; i=i+1) begin
            pk[i] <= 32'b0;
            e0[i] <= 32'b0;
            e1[i] <= 32'b0;
        end
        
        trigger = 1'b0;
        trigger2 = 1'b0;
    
        resetn = 1'b0;
        start  = 1'b0;
        instruction = 3'b0;
        
        rand_valid = 1'b0;
        rand_din = 32'b0;
        
        din_load = 8'b00000000;
        din_addr = 'b0;
        din = 32'b0;
        din_done = 1'b0;
        
        request_data = 7'b0;
        request_done = 1'b0;
        #(4*period);
        
        resetn = 1'b1;
        #period
        
        
        
        // KEY GENERATION ////////////////////////////////////////////////////////
        wait (~busy);
        instruction = 3'b001;
        $fdisplay(f_out, "Key Generation started at %0t", $time);
        $display("Key Generation started at %0t", $time);
        wait (rand_request);
        #(4*period)      

        // provide randomness for sampling sigma
        wait (rand_request);
        #(4*period+delta); // here we need a delta to ensure correct simulation
        
        rand_valid = 1'b1;
        $readmemh(file_id_sk_seed, sk_seed);
        for(integer i=0; i < 8; i=i+1) begin
            rand_din    <= sk_seed[i];
            $display("Seed: %08X", sk_seed[i]);
            #period;
        end   
        
        rand_valid <= 1'b0;
        #(4*period);
        
        instruction = 3'b000;


        
        // provide randomness for sampling sigma
        wait (rand_request);
        #(4*period+delta); // here we need a delta to ensure correct simulation
        
        rand_valid = 1'b1;
        $readmemh(file_id_sigma, sigma);
        for(integer i=0; i < 8; i=i+1) begin
            rand_din    <= sigma[i];
            $display("Sigma: %08X", sigma[i]);
            #period;
        end   
        
        rand_valid <= 1'b0;
        #(4*period);
        
        instruction = 3'b000;
        
        
        
        // Check data
        wait (done);
        $fdisplay(f_out, "Key Generation done at %0t", $time);
        $display("Key Generation done at %0t", $time);
        
        // Private key h0
        #(5*period);
        request_data = 7'b0000001;
        
        trigger = 1'b0;
        wait(dout_valid);
        #period
        $readmemb(file_id_h0, h0);
        for(integer i=0; i < W/2; i=i+1) begin
//            $display("h0: %08X", dout);
            trigger = 1'b0;
            for(integer j=0; j < W/2; j=j+1) begin
                if(h0[j] == dout) begin
                    trigger =1'b1;
//                    $display("Found at postions %0d", j);
                end
            end
            if(trigger == 1'b0) begin
                $display("Index for h0 not found!");
                trigger2 = 1'b1;
            end
            #period;
        end        
        request_data = 7'b0000000; 
        
        if(trigger2 == 1'b0) begin
            $fdisplay(f_out, "Private key h0 correct!");
            $display("Private key h0 correct!");
        end 
        else begin
            $fdisplay(f_out, "Private key h0 wrong!");
            $display("Private key h0 wrong!");
        end
        
        #period;


        // Private key h1
        #(5*period);
        request_data = 7'b0000010;
        
        trigger = 1'b0;
        trigger2 = 1'b0;
        wait(dout_valid);
        #period   
        $readmemb(file_id_h1, h1);
        for(integer i=0; i < W/2; i=i+1) begin
            trigger = 1'b0;
            for(integer j=0; j < W/2; j=j+1) begin
                if(h1[j] == dout) begin
                    trigger =1'b1;
                end
            end
            if(trigger == 1'b0) begin
                $display("Index for h1 not found!");
                trigger2 = 1'b1;
            end
            #period;
        end        
        request_data = 7'b0000000; 

        if(trigger2 == 1'b0) begin
            $fdisplay(f_out, "Private key h1 correct!");
            $display("Private key h1 correct!");
        end 
        else begin
            $fdisplay(f_out, "Private key h1 wrong!");
            $display("Private key h1 wrong!");
        end
        
        #period;        
    

       // Private key sigma
        #(5*period);
        request_data = 7'b0000100;
        
        trigger = 1'b0;
        wait(dout_valid);
        #period
        $readmemh(file_id_sigma, sigma);
        for(integer i=0; i < 8; i=i+1) begin
            if(sigma[i] != dout) begin
                trigger = 1'b1;
            end
            #period;
        end    
        request_data = 7'b0000000;     
        
        if(trigger == 1'b0) begin
            $fdisplay(f_out, "Private key sigma correct!");
            $display("Private key sigma correct!");
        end 
        else begin
            $fdisplay(f_out, "Private key sigma wrong!");
            $display("Private key sigma wrong!");
        end
        
        #period;       
        
                
        // Public key h
         #(5*period);
         request_data = 7'b0001000;
         
         trigger = 1'b0;
         wait(dout_valid);
         #period
         $readmemh(file_id_pk, pk);
         for(integer i=0; i < DWORDS; i=i+1) begin
            //$display("h: %08X", pk[i]);
             if(pk[i] != dout) begin
                 trigger = 1'b1;
                 $display("Found wrong chunk at address: %0d", i);
             end
             #period;
         end   
         request_data = 7'b0000000;      
         
         if(trigger == 1'b0) begin
             $fdisplay(f_out, "Public key h correct!");
             $display("Public key h correct!");
         end 
         else begin
             $fdisplay(f_out, "Public key h wrong!");
             $display("Public key h wrong!");
         end
         
         #period;  

         wait(~busy);
         $fdisplay(f_out, "Starting reseting memory at %0t", $time);
         #period;
         request_done <= 1'b1;
         #(5*period);
         request_done <= 1'b0;
         wait(~busy);     
         $fdisplay(f_out, "Reseting finished at %0t", $time);
        
         resetn <= 1'b0;
         #(10*period);
         resetn <= 1'b1;
         #period;



        trigger = 1'b0;
    
        resetn = 1'b0;
        start  = 1'b0;
        instruction = 3'b0;
        
        rand_valid = 1'b0;
        rand_din = 32'b0;
        
        din_load = 8'b00000000;
        din_addr = 'b0;
        din = 32'b0;
        din_done = 1'b0;
        
        request_data = 7'b0;
        request_done = 1'b0;
        #(4*period);
        
        resetn = 1'b1;
        #period
        
                 
        
        
        // ENCAPSULATION /////////////////////////////////////////////////////////
        // read public key
        din_load = 8'b00000001;
        #period;
        
        $readmemh(file_id_pk, pk);
        for(integer i=0; i < DWORDS; i=i+1) begin
            din         <= pk[i];
            din_addr    <= LOGDWORDS'(i);
            #period;
        end
        
        din_load = 8'b00000000;
        din_done = 1'b1;
        #period;
        
        // start computation
        wait (~busy);
        #period;
        din_done = 1'b0;
        
        instruction = 3'b010; // encaps 
        $fdisplay(f_out, "Encapsulation started at %0t", $time);
        $display("Encapsulation started at %0t", $time);
        #(2*period);
        instruction = 3'b000; // encaps 
        
        // provide randomness for sampling m
        wait (rand_request);
        #(4*period+delta); // here we need a delta to ensure correct simulation
        
        rand_valid = 1'b1;
        $readmemh(file_id_m, m);
        for(integer i=0; i < 8; i=i+1) begin
            rand_din    <= m[i];
            #period;
        end    
        
        rand_valid = 1'b0;
        rand_din = 32'b0;
        
        wait (done);
        $fdisplay(f_out, "Encapsulation done at %0t", $time);
        $display("Encapsulation done at %0t", $time);
        
        // Check data
        // Shared key
        #(5*period);
        request_data = 7'b1000000;
        
        trigger = 1'b0;
        wait(dout_valid);
        #period
        $readmemh(file_id_k, k);
        for(integer i=0; i < 8; i=i+1) begin
            if(k[i] != dout) begin
                trigger = 1'b1;
            end
            #period;
        end      
        
        request_data = 7'b0000000;   
        
        if(trigger == 1'b0) begin
            $fdisplay(f_out, "Shared key correct!");
            $display("Shared key correct!");
        end 
        else begin
            $fdisplay(f_out, "Shared key wrong!");
            $display("Shared key wrong!");
        end
        
        #period;


        // c0
        #(5*period);
        request_data = 7'b0010000;
        
        trigger = 1'b0;
        wait(dout_valid);
        #period
        $readmemh(file_id_c0, c0);
        for(integer i=0; i < DWORDS; i=i+1) begin
            if(c0[i] != dout) begin
                trigger = 1'b1;
            end
            #period;
        end      
        
        request_data = 7'b0000000;   
        
        if(trigger == 1'b0) begin
            $fdisplay(f_out, "Cryptogram c0 correct!");
            $display("Cryptogram c0 correct!");
        end 
        else begin
            $fdisplay(f_out, "Cryptogram c0 wrong!");
            $display("Cryptogram c0 wrong!");
        end
        
        #period;
                
        
        // c1
        #(5*period);
        request_data = 7'b0100000;
        
        trigger = 1'b0;
        wait(dout_valid);
        #period
        $readmemh(file_id_c1, c1);
        for(integer i=0; i < 8; i=i+1) begin
            if(c1[i] != dout) begin
                trigger = 1'b1;
            end
            #period;
        end      
        
        request_data = 7'b0000000;   
        
        if(trigger == 1'b0) begin
            $fdisplay(f_out, "Cryptogram c1 correct!");
            $display("Cryptogram c1 correct!");
        end 
        else begin
            $fdisplay(f_out, "Cryptogram c1 wrong!");
            $display("Cryptogram c1 wrong!");
        end
        
        #period;
        
        // reset memory
        wait(~busy);
        #period;
        request_done <= 1'b1;
        #(2*period);
        request_done <= 1'b0;
        wait(~busy);
        
        resetn <= 1'b0;
        #(10*period);
        resetn <= 1'b1;
        #period;
        



   // DECAPSULATION
    
   // read private key h0
   #(period+delta);
    
   wait (~busy);

   // read private key h0 compact
   wait (~busy);
   din_load = 8'b01000000;
   #period;
    
   $readmemb(file_id_h0, h0);
   for(integer i=0; i < W/2; i=i+1) begin
       din         <= {{32-int'($clog2(R_BITS)){1'b0}}, h0[i]};
       din_addr    <= LOGDWORDS'(i);
       #period;
   end
    
   din_load = 8'b00000000;
   din_done = 1'b1;
   din      = 'b0;
   din_addr = 'b0;
    
   #period;
   din_done = 1'b0;

   // read private key h1 compact
   wait (~busy);
   din_load = 8'b10000000;
   #period;
    
   $readmemb(file_id_h1, h1);
   for(integer i=0; i < W/2; i=i+1) begin
       din         <= {{32-int'($clog2(R_BITS)){1'b0}}, h1[i]};
       din_addr    <= LOGDWORDS'(i);
       #period;
   end
    
   din_load = 8'b00000000;
   din_done = 1'b1;
   din      = 'b0;
   din_addr = 'b0;
    
   #period;
   din_done = 1'b0;
        
   // read private key sigma
   wait (~busy);
   din_load = 8'b00001000;
   #period;
    
   $readmemh(file_id_sigma, sigma);
   for(integer i=0; i < 8; i=i+1) begin
       din         <= sigma[i];
       din_addr    <= LOGDWORDS'(i);
       #period;
   end
    
   din_load = 8'b00000000;
   din_done = 1'b1;
   din      = 'b0;
   din_addr = 'b0;
    
   #period;
   din_done = 1'b0;
    

   // read cryptogram c0
   wait (~busy);
   din_load = 8'b00010000;
   #period;
    
   $readmemh(file_id_c0, c0);
   for(integer i=0; i < DWORDS; i=i+1) begin
       din         <= c0[i];
       din_addr    <= LOGDWORDS'(i);
       #period;
   end
    
   din_load = 8'b00000000;
   din_done = 1'b1;
   din      = 'b0;
   din_addr = 'b0;
    
   #period;
   din_done = 1'b0;


   // read cryptogram c1
   wait (~busy);
   din_load = 8'b00100000;
   #period;
    
   $readmemh(file_id_c1, c1);
   for(integer i=0; i < 8; i=i+1) begin
       din         <= c1[i];
       din_addr    <= LOGDWORDS'(i);
       #period;
   end
    
   din_load = 8'b00000000;
   din_done = 1'b1;
   din      = 'b0;
   din_addr = 'b0;
    
   #period; 
   din_done = 1'b0;
       
        
   // start computation
   wait (~busy);
   instruction = 3'b100;
   $fdisplay(f_out, "Decapsulation started at %0t", $time);
   $display("Decapsulation started at %0t", $time);
    
   #(10*period);
   instruction = 3'b000;
    
   // Check data
   wait (done);
   $fdisplay(f_out, "Decapsulation done at %0t", $time);
   $display("Decapsulation done at %0t", $time);
    
   // Shared key
   #(5*period);
   request_data = 7'b1000000;
    
   trigger = 1'b0;
   wait(dout_valid);
   #period
   $readmemh(file_id_k, k);
   for(integer i=0; i < 8; i=i+1) begin
       if(k[i] != dout) begin
           trigger = 1'b1;
       end
       #period;
   end      
    
   request_data = 7'b0000000;   
    
   if(trigger == 1'b0) begin
       $fdisplay(f_out, "Shared key correct!");
       $display("Shared key correct!");
   end 
   else begin
       $fdisplay(f_out, "Shared key wrong!");
       $display("Shared key wrong!");
   end
    
   #period;

   wait(~busy);
   #period;
   request_done <= 1'b1;
   #(2*period);
   request_done <= 1'b0;
   wait(~busy);  
    
    $fclose(f_out);

    end
    
endmodule
