`timescale 1ns/1ps



////////////////////////////////
//REGISTERS
////////////////////////////////
module shiftrne (R, L, E, w, Clock, Q);
    parameter n = 16;

    input  [n-1:0] R;
    input  L, E, w, Clock;
    output reg [n-1:0] Q;

    integer k;

    always @(posedge Clock) begin
        if (L) begin
          Q <= R[n-1] ? ~R+1 : R;       // Load input (ALWAYS POSITIVE)
          //$display("Positive B: %b", Q);
        end
        else if (E) begin
            // Shift right with new bit inserted at MSB
            for (k = n-1; k > 0; k = k-1)
                Q[k-1] <= Q[k];
            
          	Q[n-1] <= w;                   // Insert shift-in bit at MSB
        end
    end
endmodule

module shiftlne (R, L, E, w, Clock, Q);
    parameter n = 16;

    input  [n-1:0] R;
    input  L, E, w, Clock;
    output reg [n-1:0] Q;

    integer k;

    always @(posedge Clock) begin
        if (L) begin
          Q <= R[n-1] ? ~R+1 : R;
          //$display("Positive A: %b", Q);
        end
        else if (E) begin
            // Shift left with new bit inserted at LSB
            for (k = 0; k < n-1; k = k+1)
                Q[k+1] <= Q[k];

            Q[0] <= w;                     // Insert shift-in bit at LSB
        end
    end
endmodule

module regne (R, Clock, Resetn, E, Q);
    parameter n = 16;

    input  [n-1:0] R;
    input  Clock, Resetn, E;
    output reg [n-1:0] Q;

    always @(posedge Clock, negedge Resetn) begin
        if (!Resetn)
            Q <= {n{1'b0}};    // Reset to 0
        else if (E)
            Q <= R;            // Load when enabled 
    end
endmodule

////////////////////////////////
//MULTIPLEXER
////////////////////////////////
module mux64to1 (Q_chain, sel, Y);
	parameter N = 16, NUM_REG = 64;
  	
  	input wire [NUM_REG*N-1:0] Q_chain;
  	input wire [5:0] sel;
  	output wire [N-1:0] Y; // selected 16-bit output
  	
    // Extract selected 16-bit slice
    assign Y = Q_chain[sel*N +: N];

endmodule

////////////////////////////////
//MULTIPLIER
////////////////////////////////

module multiply (
    Clock, Resetn, LA, LB, s, DataA, DataB, P, Done
);
    parameter n = 16;

    input  Clock, Resetn, LA, LB, s;
    input  [n-1:0] DataA, DataB;
    output [n+n-1:0] P;
    output reg Done;

    wire z;
    reg [n+n-1:0] DataP;
    wire [n+n-1:0] A, Sum;
    reg  [1:0] y, Y;
    wire [n-1:0] B;
    reg EA, EB, EP, rstSum;
  	wire Aneg, Bneg;
  	wire [n+n-1:0] Pint; //For the absolute multiplication
    integer k;

    // Control states
    parameter S1 = 2'b00,
              S2 = 2'b01,
              S3 = 2'b10;

    //------------------------------------------------------------
    // State Transition Table
    //------------------------------------------------------------
    always @(s, y, z) begin : State_table
        case (y)
            S1: if (s == 0)
                    Y = S1;
                else
                    Y = S2;

            S2: if (z == 0)
                    Y = S2;
                else
                    Y = S3;

            S3: if (s == 1)
                    Y = S3;
                else
                  	Y = S1;

            default: Y = 2'bxx;
        endcase
    end
	
  	// ------------------------------------------------------------
	// Debugging: print current P, Pint, ShiftA, ShiftB
	// ------------------------------------------------------------
	/*always @(posedge Clock) begin
    	$display("Time=%0t | LA=%b LB=%b EA=%b EB=%b EP=%b", $time, LA, LB, EA, EB, EP);
    	$display("DataA=%b | ShiftA=%b", DataA, A);
    	$display("DataB=%b | ShiftB=%b", DataB, B);
    	$display("DataP=%b | Pint=%b | P=%b", DataP, Pint, P);
	end*/
    //------------------------------------------------------------
    // State Flip-Flops
    //------------------------------------------------------------
    always @(posedge Clock, negedge Resetn) begin : State_flipflops
      	if (!Resetn)
            y <= S1;
        else if (!s)
        	y <= S1;   // Reset FSM when s=0
      	else
            y <= Y;
      	
    end
  
  	

    //------------------------------------------------------------
    // FSM Outputs
    //------------------------------------------------------------
    always @(s, y, B[0]) begin : FSM_outputs
        // Defaults
        EA   = 0;
        EB   = 0;
        EP   = 0;
        Done = 0;
        rstSum = 0;

        case (y)
            S1: begin
                EP = 1;
            end

            S2: begin
                EA   = 1;
                EB   = 1;
                rstSum = 1;
                if (B[0])
                    EP = 1;
                else
                    EP = 0;
            end

            S3: begin
                Done = 1;
            end
        endcase
    end

    //------------------------------------------------------------
    // Datapath
    //------------------------------------------------------------

    shiftrne ShiftB (
      	.R(DataB), //Input Data
      	.L(LB), //Load 
      	.E(EB), //Enable
     	.w(1'b0),//Shift In Bit 
        .Clock(Clock),
      	.Q(B) //Current Reg
    );
    defparam ShiftB.n = 16;

    shiftlne ShiftA (
      .R({{n{DataA[n-1]}}, DataA}),
        .L(LA),
        .E(EA),
        .w(1'b0),
        .Clock(Clock),
        .Q(A)
    );
    defparam ShiftA.n = 32;
	
  	assign Aneg = DataA[n-1];
	assign Bneg = DataB[n-1];
    
  	assign z   = (B == 0);
    assign Sum = A + Pint;

    //------------------------------------------------------------
    // 2n-bit 2-to-1 Mux for P input
    //------------------------------------------------------------
  always @(rstSum, Sum, Resetn) 
        for (k = 0; k < (n+n); k = k+1)
          DataP[k] = (!rstSum || !Resetn) ? 1'b0 : Sum[k]; // only reset on global Resetn

    regne RegP (
        .R(DataP),
        .Clock(Clock),
        .Resetn(Resetn),
        .E(EP),
      	.Q(Pint)
    );
    defparam RegP.n = 32;

  	assign P = (Aneg ^ Bneg) ? (~Pint + 1): Pint;
  
  
endmodule


////////////////////////////////
//FIFO
////////////////////////////////
module fircoreFIFO (Clock1, Clock2, Resetn, valid_in, din, valid_out, Q);
    parameter DATA_WIDTH = 16;

    input  Clock1, Clock2, Resetn, valid_in;
    input  wire [DATA_WIDTH-1:0] din;

    output reg  valid_out;        
    output reg [DATA_WIDTH-1:0] Q;

    // ---------------------------------------------------------
    // CLOCK 1 DOMAIN (Slow - 10 kHz)
    // ---------------------------------------------------------
    reg [DATA_WIDTH-1:0] queue;
    reg input_toggle;  // This toggles every time we get valid data

    always @(posedge Clock1 or negedge Resetn) begin
        if (!Resetn) begin
            queue <= 0;
            input_toggle <= 0;
        end else if (valid_in) begin
            queue <= din;
            // Flip the bit. 0->1, or 1->0.
            // This change signals "New Data" to the other domain.
            input_toggle <= ~input_toggle; 
        end
    end

    // ---------------------------------------------------------
    // CLOCK 2 DOMAIN (Fast - 100 MHz)
    // ---------------------------------------------------------
    reg [2:0] sync_chain; // Synchronizer + Edge Detector history
    wire toggle_event;

    always @(posedge Clock2 or negedge Resetn) begin
        if (!Resetn) begin
            sync_chain <= 0;
            Q <= 0;
            valid_out <= 0;
        end else begin
            // 1. Shift the toggle signal into our domain
            // sync_chain[0] = Unstable (Raw input)
            // sync_chain[1] = Stable (Synchronized)
            // sync_chain[2] = Delayed (Previous value for edge detect)
            sync_chain <= {sync_chain[1:0], input_toggle};

            // 2. Detect ANY change (0->1 or 1->0)
            // If the synchronized value (bit 1) is different from the previous value (bit 2),
            // it means the toggle flipped in the other domain.
            if (sync_chain[1] != sync_chain[2]) begin
                Q <= queue;      // Capture data
                valid_out <= 1;  // Pulse valid output
            end else begin
                valid_out <= 0;
            end
        end
    end

endmodule

////////////////////////////////
//REG
////////////////////////////////
module fircoreREG(inputX, Clock, Resetn, E, sel, Q);
    parameter N = 16, NUM_REG = 64;
  
  	input wire [N-1:0] inputX;
    input wire Clock;
    input wire Resetn;
    input wire E;
  	input wire [5:0] sel;
  	output wire [N-1:0] Q;
  
    // Internal wires to connect the registers
    wire [N-1:0] Q_wires [0:NUM_REG-1];
   	wire [NUM_REG*N-1:0] Q_chain;


    // Generate 64 regne instances
    genvar i;
    generate
        for (i = 0; i < NUM_REG; i = i + 1) begin
            if (i == 0) begin
                // First register takes inputX
                regne #(.n(N)) R_inst (
                    .R(inputX),
                    .Clock(Clock),
                    .Resetn(Resetn),
                    .E(E),
                    .Q(Q_wires[i])
                );
            end else begin
                // All other registers take output of previous register
                regne #(.n(N)) R_inst (
                    .R(Q_wires[i-1]),
                    .Clock(Clock),
                    .Resetn(Resetn),
                    .E(E),
                    .Q(Q_wires[i])
                );
            end
        end
    endgenerate
  	
  	//Get output chain for MUX
    genvar j;
    generate
        for (j = 0; j < NUM_REG; j = j + 1) begin
            assign Q_chain[j*N +: N] = Q_wires[j];
        end
    endgenerate
	
  	mux64to1 #(.N(16), .NUM_REG(64)) MUX (
    	.Q_chain(Q_chain),   // full register chain input
    	.sel(sel),       // 6-bit select line
      	.Y(Q)          // selected 16-bit output
    );
  	
endmodule

////////////////////////////////
//CMEM
////////////////////////////////
module fircoreCMEM (Clock, Resetn, cload, caddr, cin, raddr, Q);
	parameter N=64, DATA_WIDTH=16;
  	
  	input Clock, Resetn, cload;
  	input  wire [5:0] caddr;           
  	input wire [5:0] raddr;				
  	input  wire [DATA_WIDTH-1:0] cin;     
  	output wire  [DATA_WIDTH-1:0] Q;
  
  	//Internal Memory Register
  	reg [DATA_WIDTH-1:0] mem [0:N-1];    

  
    integer i;
    // Synchronous reset + write logic
    always @(posedge Clock) begin
        if (!Resetn) begin
            for (i = 0; i < N; i=i+1)
                mem[i] <= 0;
        end else if (cload) begin
            mem[caddr] <= cin;
        end
    end
  	
  	//Read
  	assign Q = mem[raddr];

endmodule


////////////////////////////////
//ALU
////////////////////////////////
module fircoreALU (
    Clock, Resetn, LA, LB, s, DataA, DataB, Q, Done, acc_clr
);
    parameter n = 16;

    input  Clock, Resetn, LA, LB, s, acc_clr;
    input  [n-1:0] DataA, DataB;
    output [n-1:0] Q;    // Q7.9 output
    output reg Done;

    // Internal wires
    wire [n+n-1:0] P;         // 32-bit product Q2.30
    wire Done_mul;

    //------------------------------------------------------------
    // Done signal and debug
    //------------------------------------------------------------
    /*always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            Done <= 0;
            $display("DEBUG: Reset Done to 0 at time %0t", $time);
        end else begin
            // Debug prints
          $display("DEBUG: Clock=%0t | Done_mul=%b, Done_prev=%b, Done=%b, sum=%0d (0b%b), Q_reg=%0d, P=%0d (0b%b)", 
                 $time, Done_mul, Done_prev, Done, sum, sum, Q_reg, P, P);
        end
    end*/
    // -------------------------
    // Accumulator
    // --------------------------
  	reg signed [32:0] sum;
    reg [15:0] Q_reg;
    reg Done_prev;

    always @(posedge Clock or negedge Resetn) begin
      //$display("[%0t] Current Q = %b (%0d), Done_mul=%b, Done_prev=%b, Done=%b, P=(0x%h)",$time, Q, Q, Done_mul, Done_prev, Done, P);
      	if (!Resetn) begin
            sum       <= 0;
            Q_reg     <= 0;
            Done_prev <= 0;
        end else begin
            // ADD THIS IF-STATEMENT
            if (acc_clr) begin
                 sum   <= 0;
                 Q_reg <= 0;
            end
          
          	Done_prev <= Done_mul;
			
            /*if (!s) begin                 // Reset accumulator and allow new FIR sequence
                sum   <= 0;
                Q_reg <= 0;
            end*/
            if (Done_mul && !Done_prev) begin  // rising edge of Done_mul
             	sum  <= sum + $signed(P); //BLOCKING?
              	Q_reg <= (sum + $signed(P)) >>> 21;  // Q7.9
              //$display("---MULIPLICATION DONE----");
            end
        end
    end

    assign Q = Q_reg;

    //------------------------------------------------------------
    // Multiplier instance
    //------------------------------------------------------------
    multiply U_mult (
        .Clock(Clock),
        .Resetn(Resetn),
        .LA(LA),
        .LB(LB),
        .s(s),
        .DataA(DataA),
        .DataB(DataB),
        .P(P),
        .Done(Done_mul)
    );
    defparam U_mult.n = n; 

    //------------------------------------------------------------
    // Done signal: high for one clock after Q_reg update
    //------------------------------------------------------------
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            Done <= 0;
        end else if (!s) begin
            Done <= 0;                  // clear Done when starting a new FIR sequence
        end else begin
            Done <= (Done_mul && !Done_prev);  // one-cycle pulse
        end
    end

endmodule


module fircoreFSM (
    input wire clk,
    input wire rstn,
    input wire start_calc,       // From FIFO valid_out
    input wire alu_done,         // From ALU Done
    
    output reg [5:0] addr_sel,   // Controls MUX and CMEM address
    output reg LA,               // Load A (ALU)
    output reg LB,               // Load B (ALU)
    output reg s,                // Start (ALU)
    output reg acc_clr,          // Signal to clear Accumulator
    output reg valid_out         // System output valid
);

    localparam IDLE      = 3'b000;
    localparam LOAD_VARS = 3'b001;
    localparam EXECUTE   = 3'b010;
    localparam WAIT_DONE = 3'b011;
    localparam RESET_MUL = 3'b100; // New state to pulse s=0
    localparam DONE      = 3'b101;

    reg [2:0] state, next_state;
    reg [5:0] loop_cnt;

    // Sequential Logic
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            loop_cnt <= 0;
        end else begin
            state <= next_state;
            if (state == RESET_MUL)
                loop_cnt <= loop_cnt + 1;
            else if (state == IDLE)
                loop_cnt <= 0;
        end
    end

    // Combinational Logic
    always @(*) begin
        // Defaults
        LA = 0; LB = 0; s = 0;
        acc_clr = 0;
        valid_out = 0;
        addr_sel = loop_cnt;
        next_state = state;

        case (state)
            IDLE: begin
                s = 0;
                // If we are starting a new sample, we MUST clear the previous sum
                if (start_calc) begin
                    acc_clr = 1; // Pulse clear for one cycle
                    next_state = LOAD_VARS;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_VARS: begin
                // Load values first
                LA = 1; 
                LB = 1;
                s  = 0; // Keep s low while loading
                next_state = EXECUTE;
            end

            EXECUTE: begin
                // Start the multiply FSM
                s = 1; 
                next_state = WAIT_DONE;
            end
            
            WAIT_DONE: begin
                s = 1; // Hold s=1 until Done goes high
                if (alu_done)
                    next_state = RESET_MUL;
                else
                    next_state = WAIT_DONE;
            end

            RESET_MUL: begin
                // Reset the Multiplier FSM (s=0) so it can run again
                s = 0; 
                
                if (loop_cnt == 63)
                    next_state = DONE;
                else
                    next_state = LOAD_VARS; // Process next tap
            end

            DONE: begin
                valid_out = 1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule


module fircore (
    input wire clk1,            // Input Domain Clock
    input wire clk2,            // Processing Domain Clock
    input wire rstn,            // Active Low Reset
    
    // FIFO/Data Inputs
    input wire valid_in,
    input wire [15:0] din,
    
    // CMEM Programming Inputs
    input wire [15:0] cin,
    input wire [5:0] caddr,
    input wire cload,
    
    // System Outputs
    output wire [15:0] dout,
    output wire valid_out
);

    // Internal Wires
    wire [15:0] fifo_data_out;
    wire fifo_valid_out;
    
    wire [15:0] reg_out_Q;
    wire [15:0] cmem_out_Q;
    
    wire [5:0] fsm_addr_sel;
    wire fsm_LA;
    wire fsm_LB;
    wire fsm_s;
    wire alu_done_sig;
    wire acc_clr; // <--- Added missing wire declaration
    
    // ------------------------------------------------------------
    // 1. FIFO
    // Bridges clk1 (input) to clk2 (processing)
    // ------------------------------------------------------------
    fircoreFIFO u_fifo (
        .Clock1     (clk1),
        .Clock2     (clk2),
        .Resetn     (rstn),
        .valid_in   (valid_in),
        .din        (din),
        .valid_out  (fifo_valid_out),
        .Q          (fifo_data_out)
    );

    // ------------------------------------------------------------
    // 2. REG (Datapath Registers)
    // Per instruction: FIFO Q -> inputX, FIFO valid_out -> E
    // ------------------------------------------------------------
    fircoreREG #(.N(16), .NUM_REG(64)) REG (
        .inputX     (fifo_data_out), 
        .Clock      (clk2),
        .Resetn     (rstn),
        .E          (fifo_valid_out), // Shifts when FIFO has data
        .sel        (fsm_addr_sel),   // Controlled by FSM to select Tap
        .Q          (reg_out_Q)
    );

    // ------------------------------------------------------------
    // 3. CMEM (Coefficient Memory)
    // Stores filter coefficients
    // ------------------------------------------------------------
    fircoreCMEM #(.N(64), .DATA_WIDTH(16)) CMEM (
        .Clock      (clk2),
        .Resetn     (rstn),
        .cload      (cload),
        .caddr      (caddr),
        .cin        (cin),
        .raddr      (fsm_addr_sel),  // Controlled by FSM
        .Q          (cmem_out_Q)
    );

    // ------------------------------------------------------------
    // 4. ALU (Multiplier + Accumulator)
    // Calculates: Sum += DataA * DataB
    // ------------------------------------------------------------
    fircoreALU ALU (
        .Clock      (clk2),
        .Resetn     (rstn),
        .LA         (fsm_LA),        // Load A
        .LB         (fsm_LB),        // Load B
        .s          (fsm_s),         // Start/Accumulate
        .DataA      (reg_out_Q),     // From REG
        .acc_clr    (acc_clr),       // <--- Added missing comma here
        .DataB      (cmem_out_Q),    // From CMEM
        .Q          (dout),          // Final Result
        .Done       (alu_done_sig)
    );

    // ------------------------------------------------------------
    // 5. Control FSM
    // Orchestrates the calculation loop
    // ------------------------------------------------------------
    fircoreFSM FSM (
        .clk        (clk2),
        .rstn       (rstn),
        .start_calc (fifo_valid_out), // Triggered by FIFO valid
        .alu_done   (alu_done_sig),
        .addr_sel   (fsm_addr_sel),   // Drives MUX and CMEM address
        .acc_clr    (acc_clr),        // <--- Added missing comma here
        .LA         (fsm_LA),
        .LB         (fsm_LB),
        .s          (fsm_s),
        .valid_out  (valid_out)
    );

endmodule