// CPU32 ALU
//
// Copyright 2012, Brian Swetland.  Use at your own risk.

module alu (
	input [3:0] opcode,
	input [31:0] left,
	input [31:0] right,
	output reg [31:0] out
	);

wire [31:0] rbit;
assign rbit = (1 << right[4:0]);

always @ (*)
	case (opcode)
	4'b0000: out <= (left | right);
	4'b0001: out <= (left & right);
	4'b0010: out <= (left + right);
	4'b0011: out <= (left - right);
	4'b0100: out <= (left << right[4:0]);
	4'b0101: out <= (left >> right[4:0]);
	4'b0110: out <= (left ^ right);
	4'b0111: out <= (left & rbit) ? 1 : 0;
	4'b1000: out <= (left == right) ? 1 : 0;
	4'b1001: out <= (left <  right) ? 1 : 0;
	4'b1010: out <= (left >  right) ? 1 : 0;
	4'b1011: out <= 0;
	4'b1100: out <= (left | rbit);
	4'b1101: out <= (left & ~rbit);
	4'b1110: out <= right;
	4'b1111: out <= { right[15:0], left[15:0] };
	endcase
endmodule
