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

initial begin
	$dumpfile("testbench.vcd");
	$dumpvars(0,testbench);
end

initial #400 $finish;

initial
	$monitor("%05t: pc=%h ir=%h R> %h %h %h %h",
		$time, cpu.pc, cpu.ir,
		cpu.REGS.R[0],
		cpu.REGS.R[1],
		cpu.REGS.R[2],
		cpu.REGS.R[3]
		);

endmodule

