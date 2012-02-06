// Copyright 2012, Brian Swetland.  If it breaks, you keep both halves.

`timescale 1ns/1ns

module uart(
	input clk,
	input bclk,
	input reset,
	input [7:0] wdata,
	output [7:0] rdata,
	input we,
	output tx
	);

reg [7:0] tx_fifo;
reg [12:0] tx_shift;
reg [3:0] tx_count;

wire tx_busy;
reg tx_start;

assign rdata = { 7'h0, tx_busy };
assign tx = tx_shift[0];
assign tx_busy = (tx_count != 0);

always @(posedge bclk, posedge reset) begin
	if (reset) begin
		tx_count <= 0;
		tx_shift <= 13'hFFFF;
	end else if (tx_busy) begin
		tx_shift <= { 1'b0, tx_shift[12:1] };
		tx_count <= ( tx_count - 1 );
	end else if (tx_start) begin
		tx_shift[12:1] <= { 2'b11, tx_fifo, 1'b0 };
		tx_count <= 11;
	end
end

always @(posedge clk) begin
	if (reset) begin
		tx_start <= 0;
	end else begin
		if (tx_busy)
			tx_start <= 0;
		else if (we) begin
			tx_fifo <= wdata;
			tx_start <= 1;
		end
	end
end
endmodule

