`timescale 1ns/1ps

//REGULAR REGISTER
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

//MULTIPLEXER
module mux64to1 (Q_chain, sel, Y);
	parameter N = 16, NUM_REG = 64;
  	
  	input wire [NUM_REG*N-1:0] Q_chain;
  	input wire [5:0] sel;
  	output wire [N-1:0] Y; // selected 16-bit output
  	
    // Extract selected 16-bit slice
    assign Y = Q_chain[sel*N +: N];

endmodule

//COMBINATIONAL CORE
module fircoreREG #(parameter N = 16, parameter NUM_REG = 64)(inputX, Clock, Resetn, E, sel, Q);
  
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

