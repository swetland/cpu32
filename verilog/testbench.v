// CPU32 Test Bench - For testing in iverilog.
//
// Copyright 2012, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns

module testbench;

reg clk, reset;
wire [31:0] romaddr, romdata, ramaddr, ramrdata, ramwdata;
wire ramwe;

initial begin
	clk = 0;
	reset = 0;
	#1 reset = 1;
	#19 reset = 0;
	end

always
	#10 clk = ~clk;

wire [7:0] urdata;

cpu32 cpu(
	.clk(clk),
	.reset(reset),
	.i_addr(romaddr),
	.i_data(romdata),
	.d_data_r(ramrdata),
//	.d_data_r({24'b0,urdata}),
	.d_data_w(ramwdata),
	.d_addr(ramaddr),
	.d_data_we(ramwe)
	);

rom #(32,8) rom(
	.addr(romaddr[9:2]),
	.data(romdata)
	);

syncram #(32,8) ram(
	.clk(clk),
	.addr(ramaddr[9:2]),
	.rdata(ramrdata),
	.wdata(ramwdata),
	.we(ramwe)
	);


/*
wire tx;
uart uart0(
	.clk(clk),
	.reset(reset),
	.wdata(ramwdata[7:0]),
	.rdata(urdata),
	.we(ramwe & (ramaddr[31:28] == 4'hE)),
	.tx(tx)
	);
*/

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
	if (cpu.hazard_rrw)
		$display("PC> %h I> HAZARD", cpu.pc);
	else if (!reset)
	$display("PC> %h I> %h  R> %h %h %h %h %h %h %h %h",
		cpu.pc, cpu.ir,
		cpu.REGS.R[0],
		cpu.REGS.R[1],
		cpu.REGS.R[2],
		cpu.REGS.R[3],
		cpu.REGS.R[11],
		cpu.REGS.R[12],
		cpu.REGS.R[13],
		cpu.REGS.R[14]
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

