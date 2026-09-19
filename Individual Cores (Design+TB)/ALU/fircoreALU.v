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
      .R({{n{DataA[15]}}, DataA}),
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


module fircoreALU (
    Clock, Resetn, LA, LB, s, DataA, DataB, Q, Done
);
    parameter n = 16;

    input  Clock, Resetn, LA, LB, s;
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
            $display("DEBUG: Clock=%0t | Done_mul=%b, Done_prev=%b, Done=%b, sum=%0d, Q_reg=%0d, P=%0d (0x%h)", 
                 $time, Done_mul, Done_prev, Done, sum, Q_reg, P, P);
        end
    end*/
    // --------------------------
    // Accumulator
    // --------------------------
    reg signed [31:0] sum;
    reg [15:0] Q_reg;
    reg Done_prev;

    always @(posedge Clock or negedge Resetn) begin
      //$display("[%0t] Current Q = %b (%0d), Done_mul=%b, Done_prev=%b, Done=%b, P=(0x%h)",$time, Q, Q, Done_mul, Done_prev, Done, P);
      	if (!Resetn) begin
            sum       <= 0;
            Q_reg     <= 0;
            Done_prev <= 0;
        end else begin
            Done_prev <= Done_mul;

            /*if (!s) begin                 // Reset accumulator and allow new FIR sequence
                sum   <= 0;
                Q_reg <= 0;
            end
            else*/ if (Done_mul && !Done_prev) begin  // rising edge of Done_mul
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

