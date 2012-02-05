// Copyright 2012, Brian Swetland.  If it breaks, you keep both halves.

`timescale 1ns/1ns

module uart(
	input clk,
	input reset,
	input [8:0] bdiv,
	input [7:0] wdata,
	input we,
	output tx
	);

reg bclk;
reg [8:0] bcnt;
reg [7:0] thr;

reg [7:0] tx_fifo;
reg [10:0] tx_shift;
wire tx_busy;
reg tx_start;

assign tx = tx_shift[0];

assign tx_busy = (tx_shift[10:1] != 0);

always @(posedge bclk, posedge reset) begin
	if (reset)
		tx_shift <= 11'h001;
	else if (tx_busy) 
		tx_shift = { 1'b0, tx_shift[10:1] };
	else if (tx_start) begin
		tx_shift <= { 1'b1, tx_fifo, 2'b01 };
	end
end

always @(posedge clk) begin
	if (reset) begin
		bcnt <= 0;
		bclk <= 0;
		tx_start <= 0;
	end else begin
		if (bcnt == bdiv) begin
			bcnt <= 9'h0;
			bclk <= !bclk;
		end else begin
			bcnt <= bcnt + 1;
			bclk <= bclk;
		end
		if (tx_busy)
			tx_start <= 0;
		else if (we) begin
			tx_fifo = wdata;
			tx_start <= 1;
		end
	end
end
endmodule

