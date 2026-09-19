`timescale 1ns/1ps
module fircoreFIFO (Clock1, Clock2, Resetn, valid_in, din, valid_out, Q);
    parameter DATA_WIDTH = 16;

    input  Clock1, Clock2, Resetn, valid_in;
    input  wire [DATA_WIDTH-1:0] din;

    output reg  valid_out;       
    output reg [DATA_WIDTH-1:0] Q;

    // Internal register - Clock1 domain
    reg [DATA_WIDTH-1:0] queue;

    // Synchronizer for valid_in - Clock2 domain
    reg valid_ff1, valid_ff2;

    // Edge detect - Clock2 domain
    wire valid_rising_edge;

    
    // CLOCK1 DOMAIN — latch input
    always @(posedge Clock1 or negedge Resetn) begin
        if (!Resetn) begin
            queue <= 0;
        end else if (valid_in) begin
            queue <= din;    // transparent latch, no need to save data
        end
      //$display("CLOCK 1: current queue = %d, and din = %d", queue, din);
    end

    // CLOCK2 DOMAIN — synchronize valid_in
    always @(posedge Clock2 or negedge Resetn) begin
        if (!Resetn) begin
            valid_ff1 <= 0;
            valid_ff2 <= 0;
        end else begin
            valid_ff1 <= valid_in;   // sample async valid_in
            valid_ff2 <= valid_ff1;  // metastability protection
        end
      //$display("CLOCK2 current queue = %d", queue);
    end

    assign valid_rising_edge = valid_ff1 & ~valid_ff2; // detects rising edge
  
    // CLOCK2 DOMAIN — capture queue and pulse valid_out
    always @(posedge Clock2 or negedge Resetn) begin
        if (!Resetn) begin
            Q <= 0;
            valid_out <= 0;
        end else begin
            valid_out <= 0; // default low

            if (valid_rising_edge) begin
              	//$display("Valid_in Rising Edge clk2, current queue = %d", queue);
                Q <= queue;   // capture stable value from Clock1
                valid_out <= 1;       // pulse for one cycle
            end
        end
    end

endmodule

