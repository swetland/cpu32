// Copyright 2012, Brian Swetland.  If it breaks, you keep both halves.

// todo: wire up a divisor register

`timescale 1ns/1ns

module uart(
	input clk,
	input reset,
	input [7:0] wdata,
	output [7:0] rdata,
	input we,
	output tx
	);

reg out;
reg busy;
reg [7:0] data;
reg [3:0] state;
wire next_bit;

counter bitcounter(
	.clk(clk),
	.reset(reset),
	.max(16'd434),
	.overflow(next_bit)
	);

assign tx = out;
assign rdata = { 7'b0, busy };

always @(posedge clk or posedge reset)
begin
	if (reset) begin
		out <= 1'b1;
		busy <= 1'b1;
		state <= 4'b0010;
		data <= 8'hFF;
	end else begin
		if (we) begin
			data <= wdata;
			busy <= 1'b1;
		end
		if (next_bit) begin
			case (state)
			4'b0000: begin state <= (busy ? 4'b0001 : 4'b0000); out <= 1'b1; end
			4'b0001: begin state <= 4'b0010; out <= 1'b0; end
			4'b0010: begin state <= 4'b0011; out <= data[0]; end
			4'b0011: begin state <= 4'b0100; out <= data[1]; end
			4'b0100: begin state <= 4'b0101; out <= data[2]; end
			4'b0101: begin state <= 4'b0110; out <= data[3]; end
			4'b0110: begin state <= 4'b0111; out <= data[4]; end
			4'b0111: begin state <= 4'b1000; out <= data[5]; end
			4'b1000: begin state <= 4'b1001; out <= data[6]; end
			4'b1001: begin state <= 4'b1010; out <= data[7]; end
			4'b1010: begin state <= 4'b0000; out <= 1'b1; busy <= 1'b0; end
			endcase
		end
	end
end

endmodule

module counter(
	input clk,
	input reset,
	input [15:0] max,
	output overflow 
	);

reg [15:0] count;

assign overflow = (count == max);

always @(posedge clk or posedge reset)
begin
	if (reset) 
		count <= 16'b0;
	else
		count <= overflow ? 16'b0 : (count + 16'b1);
end

endmodule


