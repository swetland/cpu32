// Copyright 2012, Brian Swetland

`timescale 1ns/1ns

module dualsyncram #(parameter DWIDTH=16, parameter AWIDTH=8) (
	input clk,
	input [AWIDTH-1:0] a_waddr,
	input [DWIDTH-1:0] a_wdata,
	input a_we,
	input [AWIDTH-1:0] b_waddr,
	input [DWIDTH-1:0] b_wdata,
	input b_we,
	input [AWIDTH-1:0] a_raddr,
	output reg [DWIDTH-1:0] a_rdata,
	input [AWIDTH-1:0] b_raddr,
	output reg [DWIDTH-1:0] b_rdata
	);

reg [DWIDTH-1:0] mem[0:2**AWIDTH-1];

always @(posedge clk) begin
	if (a_we)
		mem[a_waddr] <= a_wdata;
	if (b_we)
		mem[b_waddr] <= b_wdata;
	a_rdata <= mem[a_raddr];
	b_rdata <= mem[b_raddr];
end

endmodule
