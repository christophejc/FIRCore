`timescale 1ns/1ps
`define SD #0.01
`define HALF_CLOCK_PERIOD #40
`define MATLAB_OUT_FN "../../matlab/fircore/OutputY_Binary.txt"
`define QSIM_OUT_FN "./qsim.out"
`define INPUTX_FN   "../../matlab/fircore/InputX_Binary.txt"
`define INPUTCOEF_FN "../../matlab/fircore/InputCoef_Binary.txt"

module testbench();

    parameter n = 16;
    parameter N = 8;          // Number of FIR taps
    parameter NUM_INPUTS = 10; // Number of input samples (adjust to your file)

    reg clk;
    reg resetn;
    reg LA, LB, s;
    reg [n-1:0] DataA, DataB;
    wire [n-1:0] Q;
    wire Done;

    integer i, j;
    integer ret_read;
    integer qsim_out_file;
    integer matlab_out_file;
    integer inputX_file;
    integer inputCoef_file;

    reg [n-1:0] matlab_y; //TO COMPARE w/ QSIM
    reg [n-1:0] qsim_out; //TO COMPARE w/ MATLAB

    reg [n-1:0] inputX [0:NUM_INPUTS-1];
    reg [n-1:0] inputCoef [0:N-1];
    reg [n-1:0] input_buffer [0:N-1]; // shift register for past inputs

    // Instantiate FIR ALU
    fircoreALU U_fir (
        .Clock(clk),
        .Resetn(resetn),
        .LA(LA),
        .LB(LB),
        .s(s),
        .DataA(DataA),
        .DataB(DataB),
        .Q(Q),
        .Done(Done)
    );

    // Clock generation
    always begin
        `HALF_CLOCK_PERIOD;
        clk = ~clk;
    end

    // -----------------------------
    // Task to wait for Done rising edge
    // -----------------------------
    task wait_done;
        begin
            while (Done) @(posedge clk);   // wait Done low
            while (!Done) @(posedge clk);  // wait Done high
        end
    endtask

    initial begin
        // Initialize signals
        clk = 0;
        resetn = 0;
        LA = 0; LB = 0; s = 0;
        DataA = 0; DataB = 0;

	//Matlab output file (for comparison)        
	matlab_out_file = $fopen(`MATLAB_OUT_FN,"r");
	if (!matlab_out_file) begin
	    $display("Couldn't open the Matlab file.");
	    $finish;
	end

	// Open output file
        qsim_out_file = $fopen(`QSIM_OUT_FN, "w");
        if (!qsim_out_file) begin
            $display("Cannot open output file.");
            $finish;
        end
	
	$dumpfile("./fircoreALU.vcd");
	$dumpvars(0, testbench.clk, testbench.resetn, 
               testbench.U_fir.DataA, 
               testbench.U_fir.DataB, 
               testbench.qsim_out, 
               testbench.U_fir.Done);

        // Load inputX
        inputX_file = $fopen(`INPUTX_FN,"r");
        if (!inputX_file) begin
            $display("Cannot open inputX file.");
            $finish;
        end
        for (i = 0; i < NUM_INPUTS; i=i+1) begin
            ret_read = $fscanf(inputX_file, "%b\n", inputX[i]);
        end
        $fclose(inputX_file);

        // Load inputCoef
        inputCoef_file = $fopen(`INPUTCOEF_FN,"r");
        if (!inputCoef_file) begin
            $display("Cannot open inputCoef file.");
            $finish;
        end
        for (i = 0; i < N; i=i+1) begin
            ret_read = $fscanf(inputCoef_file, "%b\n", inputCoef[i]);
        end
        $fclose(inputCoef_file);

        // Release reset
        @(posedge clk);
        resetn = 1;

        // Clear input buffer
        for (i=0; i<N; i=i+1)
            input_buffer[i] = 0;

        // -----------------------------
        // FIR processing loop
        // -----------------------------
        for (i = 0; i < NUM_INPUTS; i=i+1) begin
            // Shift buffer
            for (j = N-1; j > 0; j=j-1)
                input_buffer[j] = input_buffer[j-1];
            input_buffer[0] = inputX[i];

            // Accumulate across FIR taps
            for (j = 0; j < N; j=j+1) begin
                // Load data
                DataA = input_buffer[j];
                DataB = inputCoef[j];
                LA = 1; LB = 1; 
		@(posedge clk);		
		s = 1;
                @(posedge clk);
                LA = 0; LB = 0;

                // Wait for Done rising edge
                wait_done();

                // Reset s briefly if you want independent accumulation per tap
                s = 0; @(posedge clk); s = 1;
            end

            // Write FIR output
	    qsim_out = Q;
            $fwrite(qsim_out_file, "%b\n", qsim_out);
            $display("Sample %0d: Q = %b (%0d)", i+1, Q, Q);
	    
	// ---- MATLAB COMPARISON ----
	    ret_read = $fscanf(matlab_out_file, "%b\n", matlab_y);

	    if (ret_read != 1) begin
    		$display("MATLAB output file ended early at sample %0d", i+1);
	    end else begin
    	    	if (Q !== matlab_y)
        		$display("MISMATCH at sample %0d: QSIM=%b  MATLAB=%b", i+1, Q, matlab_y);
    	    	else
        		$display("MATCH    at sample %0d: %b", i+1, Q);
	    end
	// ---------------------------		
				
	    s = 0; @(posedge clk); resetn = 0; @(posedge clk); resetn = 1; @(posedge clk);
        end

        $fclose(qsim_out_file);
	$fclose(matlab_out_file);
	
	$dumpall;
	$dumpflush;
        $display("Simulation complete. Outputs written to %s", `QSIM_OUT_FN);
        $finish;
    end

endmodule

