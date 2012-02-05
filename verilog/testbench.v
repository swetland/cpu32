// CPU32 Test Bench - For testing in iverilog.
//
// Copyright 2012, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns

module testbench;

reg clk, reset;
wire [31:0] romaddr, romdata, ramaddr, ramrdata, ramwdata;
wire ramwe;

initial
	begin
		reset = 0;
		#20
		reset = 1;
	end

always
	begin
		clk = 0;
		#10 ;
		clk = 1;
		#10 ;
	end

cpu32 cpu(
	.clk(clk),
	.i_addr(romaddr),
	.i_data(romdata),
	.d_data_r(ramrdata),
	.d_data_w(ramwdata),
	.d_addr(ramaddr),
	.d_we(ramwe)
	);

rom #(32,8) rom(
	.addr(romaddr[9:2]),
	.data(romdata)
	);

ram #(32,8) ram(
	.clk(clk),
	.addr(ramaddr[9:2]),
	.rdata(ramrdata),
	.wdata(ramwdata),
	.we(ramwe)
	);

teleprinter io(
	.clk(clk),
	.we(ramwe),
	.cs(ramaddr[31:28] == 4'hE),
	.data(ramwdata[7:0])
);

initial begin
	$dumpfile("testbench.vcd");
	$dumpvars(0,testbench);
end

initial #1000 $finish;

always @(posedge clk) begin
	if (cpu.ir == 32'hFFFFFFFF) begin
		$display("PC> EXIT");
		$finish();
	end
	if (cpu.ir == 32'hFFFFFFFE) begin
		$display("PC> ERROR");
		$finish();
	end
	$display("PC> %h I> %h  R> %h %h %h %h %h",
		cpu.pc, cpu.ir,
		cpu.REGS.R[0],
		cpu.REGS.R[1],
		cpu.REGS.R[2],
		cpu.REGS.R[14],
		cpu.REGS.R[15]
		);
end

endmodule

module teleprinter (
	input we,
	input cs,
	input clk,
	input [7:0] data
	);
	always @(posedge clk)
		if (cs & we)
			$write("%c", data);
endmodule

