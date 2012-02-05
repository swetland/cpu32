// RAM - Does not instantiate optimally on Altera FPGAs
//
// Copyright 2009, Brian Swetland.  Use at your own risk.

module ram #(parameter DWIDTH=16, parameter AWIDTH=3) (
	input clk, input we,
	input [AWIDTH-1:0] addr,
	input [DWIDTH-1:0] wdata,
	output [DWIDTH-1:0] rdata
	);

reg [DWIDTH-1:0] R[0:2**AWIDTH-1];

always @ (posedge clk)
	if (we)
		R[addr] <= wdata;

assign rdata = R[addr];
   
endmodule
