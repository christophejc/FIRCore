`timescale 1ns/1ps

module tb_fircore();

    // --------------------------------------------------------
    // Parameters & Signals
    // --------------------------------------------------------
    reg clk1; // Input Domain Clock (10 kHz)
    reg clk2; // Processing Domain Clock (100 MHz)
    reg rstn;

    // FIFO/Data Inputs
    reg valid_in;
    reg [15:0] din;

    // CMEM Programming Inputs
    reg [15:0] cin;
    reg [5:0] caddr;
    reg cload;

    // System Outputs
    wire [15:0] dout;
    wire valid_out;

    // Test Data Arrays
    reg [15:0] inputX [0:9];     
    reg [15:0] inputCoef [0:7];  
    
    integer i;

    // --------------------------------------------------------
    // Instantiate the Top-Level Module
    // --------------------------------------------------------
    fircore CORE (
        .clk1(clk1),
        .clk2(clk2),
        .rstn(rstn),
        .valid_in(valid_in),
        .din(din),
        .cin(cin),
        .caddr(caddr),
        .cload(cload),
        .dout(dout),
        .valid_out(valid_out)
    );

    // --------------------------------------------------------
    // Clock Generation
    // --------------------------------------------------------
    initial clk1 = 0;
    always #50000 clk1 = ~clk1; // 100,000ns period (10 kHz)

    initial clk2 = 0;
    always #40 clk2 = ~clk2;     // 10ns period (100 MHz)

    // --------------------------------------------------------
    // SETUP BLOCK
    // --------------------------------------------------------
    initial begin
        // Init
        rstn = 0; valid_in = 0; din = 0; cin = 0; caddr = 0; cload = 0;

        // Load Mock Data
        inputX[0] = 16'b0101000010010001;
        inputX[1] = 16'b0110011111100001;
        inputX[2] = 16'b1010000010000010;
        inputX[3] = 16'b0110100111010011;
        inputX[4] = 16'b0010000111100010;
        inputX[5] = 16'b1001100011111000;
        inputX[6] = 16'b1100011101001011;
        inputX[7] = 16'b0000110000000000;
        inputX[8] = 16'b0111010100011111;
        inputX[9] = 16'b0111011100000010;

        inputCoef[0] = 16'b1010100001011001;
        inputCoef[1] = 16'b0111100001111000;
        inputCoef[2] = 16'b0111010100001000;
        inputCoef[3] = 16'b1111110001000001;
        inputCoef[4] = 16'b0100110011011111;
        inputCoef[5] = 16'b1010010001010010;
        inputCoef[6] = 16'b1110101111111000;
        inputCoef[7] = 16'b0110101001101101;

        // 1. Reset
        #200 rstn = 1; #200;

        // 2. Program CMEM
        $display("=== [Time %0t] Programming CMEM (0-7) ===", $time);
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk2);
            caddr = i[5:0]; cin = inputCoef[i]; cload = 1;
            @(posedge clk2);
            cload = 0;
        end
        
        #1000; 
        -> start_producer;
    end

    event start_producer;

    // --------------------------------------------------------
    // PRODUCER: The Fix for "Off by 1"
    // --------------------------------------------------------
	initial begin
        @(start_producer); 
        
      $display("=== [Time %0t] STREAMING: Inputs 0 to %0d ===", $time, 10-1);
        
        // 1. Setup for Burst: valid goes HIGH and stays HIGH
        
      	@(negedge clk1);
      	valid_in = 1;$display("[Time %0t] VALID IN START", $time);

        // 2. Loop through inputs, changing DATA every clock cycle
      for (i = 0; i < 10; i = i + 1) begin
            din = inputX[i]; 
            // Wait for the next clock edge to latch this data
          	$display("[Time %0t] PRODUCER: Sent Input[%0d] (triggers output of Input[%0d])", $time, i, i);
            // valid_in remains 1 the whole time
            @(negedge clk1); 
        end

        // 3. End Burst
        valid_in = 0;

        // Flush (Optional, just to clear pipe)
      	//@(negedge clk1); din = {16{1'b0}}; valid_in = 1;
        //@(negedge clk1); valid_in = 0;

        // Wait enough time for processing to finish
        // Since we sped up clk1, we don't need 100ms anymore.
        #2000000; // Wait 2ms (plenty for 1MHz input rate)
        
        $display("\n=== [Time %0t] Simulation Complete ===", $time);
        //$fclose(f_out); 
        $finish;
    end

    // --------------------------------------------------------
    // CONSUMER
    // --------------------------------------------------------
    reg [31:0] output_cnt = 0;

    initial begin
        wait(rstn == 1);
        
        forever begin
            @(posedge clk2);
            if (valid_out) begin
                    // output_cnt 1 corresponds to Input 0
                    $display("[Time %0t] CONSUMER: Output Valid -> %b (Decimal: %0d)", 
                             $time, dout, dout);
                output_cnt = output_cnt + 1;
            end
        end
    end

endmodule