// Dual-reader / Single-writer Register File
//
// Copyright 2009, Brian Swetland.  Use at your own risk.

module regfile #(parameter DWIDTH=16, parameter AWIDTH=3) (
	input clk, input we,
	input [AWIDTH-1:0] wsel, input [DWIDTH-1:0] wdata,
	input [AWIDTH-1:0] asel, output [DWIDTH-1:0] adata,
	input [AWIDTH-1:0] bsel, output [DWIDTH-1:0] bdata
	);

reg [DWIDTH-1:0] R[0:2**AWIDTH-1];

initial begin
	R[0] <= 0;
	R[1] <= 0;
	R[2] <= 0;
	R[3] <= 0;
	R[4] <= 0;
	R[5] <= 0;
	R[6] <= 0;
	R[7] <= 0;
 end

always @ (posedge clk)
	if (we)
		R[wsel] <= wdata;

assign adata = R[asel];
assign bdata = R[bsel];
   
endmodule
