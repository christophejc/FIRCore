`timescale 1ns/1ps
`define SD #0.01
`define HALF_CLOCK_PERIOD #0.90
`define QSIM_OUT_FN "./qsim_rtl.out"

module testbench();
     
    // Parameters
    localparam N = 16;         // Bits per register
    localparam NUM_REG = 64;   // Number of registers in chain

    // DUT signals
    reg  [N-1:0] inputX;
    reg  Clock, Resetn, E;
    reg [5:0] Xsel;
    wire [N-1:0] Q;
    integer qsim_out_file;
    integer i, j;
    

    // Instantiate DUT
  fircoreREG #(.N(N), .NUM_REG(NUM_REG)) REG (
        .inputX(inputX),
        .Clock(Clock),
        .Resetn(Resetn),
        .E(E),
      	.sel(Xsel),      
      	.Q(Q)
    );

    // Clock generation: 10ns period
    
    always begin
        `HALF_CLOCK_PERIOD;
        Clock = ~Clock;
    end

    // Test sequence
    initial begin
        
        $display("---- Starting fircoreREG Testbench ----");

        // Initialize
        Clock = 0; Resetn = 0; E = 0; inputX = 0; Xsel = 0;
        @(posedge Clock);
        Resetn = 1;           // Release reset
        @(posedge Clock);

	// Open output file
        qsim_out_file = $fopen(`QSIM_OUT_FN, "w");
        if (!qsim_out_file) begin
            $display("Cannot open output file.");
            $finish;
        end

        // Shift in 10 sample values
      for (i = 0; i < 74; i = i + 1) begin
            @(posedge Clock);
            inputX = i;
            E = 1;                // Enable registers
            @(posedge Clock);
            E = 0;                // Disable load for next cycle

            $display("Cycle %0d: inputX = %0d", i, inputX);
        end

        // Wait one more cycle for all registers to settle
        @(posedge Clock);

      // Display full 1024-bit bus (using select)
        $display("\n---- READING BACK REGISTERS USING MUX ----");

        for (i = 0; i < NUM_REG; i = i + 1) begin
            @(posedge Clock);
            Xsel = i;
            @(posedge Clock);  // wait 1 cycle for mux to settle
            $display("Xsel=%0d  -> Q = %0d (0x%04h)  bits=%016b",
                      Xsel, Q, Q, Q);
	    $fwrite(qsim_out_file, "%b\n", Q);
        end
        

        $display("\n---- Simulation Complete ----");
	$fclose(qsim_out_file);        
	$finish;
    end

endmodule
           
