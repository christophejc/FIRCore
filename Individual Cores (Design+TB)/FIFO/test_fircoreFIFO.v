`timescale 1ns/1ps

module testbench();

    parameter DATA_WIDTH = 16;

    // Testbench signals
    reg Clock1;
    reg Clock2;
    reg Resetn;
    reg valid_in;
  	//reg [DATA_WIDTH-1:0] queue;
    reg [DATA_WIDTH-1:0] din;

    wire valid_out;
    wire [DATA_WIDTH-1:0] Q;

    // Instantiate your FIR synchronizer
    fircoreFIFO #(.DATA_WIDTH(DATA_WIDTH)) FIFO (
        .Clock1(Clock1),
        .Clock2(Clock2),
        .Resetn(Resetn),
        .valid_in(valid_in),
        .din(din),
      	//.queue(queue),
        .valid_out(valid_out),
        .Q(Q)
    );

    // -------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------
    // Slow Clock1
    initial Clock1 = 0;
    	always #20 Clock1 = ~Clock1;  // period = 40 ns

    // Fast Clock2
    initial Clock2 = 0;
    	always #2 Clock2 = ~Clock2;   // period = 4 ns (10x faster)

    // -------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------
    initial begin
        // Initialize signals
        Resetn    = 0;
        valid_in  = 0;
        din       = 0;

        // Release reset
        #10;
        Resetn = 1;

        // Wait a little for clocks to stabilize
        #10;

        // Send a few samples on Clock1
      	
    	repeat (5) begin
        	$display("-----------START OF LOOP-----------");

        	// Step 1 — change din
        	

        	// Step 2 — drop valid
        	valid_in <= 0;

        	// Step 3 — set valid_in = 1 at negedge
        	// so it is already high *before* the next posedge
        	@(negedge Clock1);
          	valid_in <= 1;
			din <= din + 1;
        	// Step 4 — drop it immediately at the posedge after
        	@(posedge Clock1);
        	valid_in <= 0;
    	end
       

        #10
      	valid_in <= 1;
      	// Finish simulation after some time
        #20;
	$display("\n==== TESTBENCH COMPLETE ====\n");        
	$finish;
    end

    // -------------------------------------------------------
    // Monitor outputs
    // -------------------------------------------------------
    initial begin
      $display("Time\tclk1\tclk2\tvalid_in\tdin\tvalid_out\tQ");
        $monitor("%0t\t%b\t%b\t%b\t\t%d\t\t%b\t%d",
                 $time, Clock1, Clock2, valid_in, din, valid_out, Q);
    end

endmodule


