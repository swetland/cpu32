// Dual-reader / Single-writer Register File
//
// Copyright 2009, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns

module regfile (
	input reset,
	input clk, input we,
	input [3:0] wsel, input [31:0] wdata,
	input [3:0] asel, output [31:0] adata,
	input [3:0] bsel, output [31:0] bdata
	);

reg [31:0] R[0:15];

initial
	R[4'b1111] = 32'b0;

always @ (posedge clk) begin
	if (we)
		case(wsel)
		4'b1111: ;
		default: R[wsel] <= wdata;
		endcase
//	R[4'b1111] <= 32'b0;
end

assign adata = R[asel];
assign bdata = R[bsel];
   
endmodule
