`timescale 1ns/1ps

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
    //Reset
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
