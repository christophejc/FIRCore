`timescale 1ns/1ps
`define SD #0.01
`define HALF_CLOCK_PERIOD #0.90

`timescale 1ns/1ps

module testbench();

    // Parameters
    parameter N = 64, DATA_WIDTH = 16;

    // Testbench signals
    reg Clock, Resetn, cload;
    reg [5:0] caddr;
    reg [5:0] raddr;
    reg [15:0] cin;
    wire [15:0] Q;
  	integer i;
  	integer j;

    
    fircoreCMEM CMEM (
        .Clock(Clock),
        .Resetn(Resetn),
        .cload(cload),
        .caddr(caddr),
        .raddr(raddr),
        .cin(cin),
        .Q(Q)
    );

    // Clock generation
    always begin
        `HALF_CLOCK_PERIOD;
        Clock = ~Clock;
    end

   
    initial begin
        $display("\n==== FIR CMEM TESTBENCH START ====\n");

        // Apply reset
	Clock = 0;
        Resetn = 0;
        cload = 0;
        caddr = 0;
        raddr = 0;
        cin = 0;
        @(posedge Clock);
        Resetn = 1;

        //Write values 0..63 into memory
        $display("Writing coefficients 0 through 63...");
      	for (i = 0; i < 64; i=i+1) begin
            cload = 1;
            caddr = i;
            cin = i;  // store coefficient = index
	    raddr = i;
	    @(posedge Clock);
            @(posedge Clock);
	    $display("mem[%0d] = %0d (0x%04h)", i, Q, Q);
        end
        @(posedge Clock);
        cload = 0;

        // Step 3: Read back values
        /*$display("\nReading back coefficients...");
      	for (j = 0; j < 64; j=j+1) begin
            raddr = j;
            @(posedge Clock);
          	$display("mem[%0d] = %0d (0x%04h)", j, Q, Q);
        end*/

        $display("\n==== TESTBENCH COMPLETE ====\n");
        $finish;
    end

endmodule


