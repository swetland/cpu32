// Copyright 2012, Brian Swetland.  If it breaks, you keep both halves.

`timescale 1ns/1ns

module uart_tb ();

reg clk;
reg reset;

uart uart0(
	.wdata("A"),
	.we(1),
	.reset(reset),
	.clk(clk),
	.bdiv(434)
	);

initial begin
	reset = 1;
	#30 ;
	reset = 0;
end

always begin
	clk = 0;
	#10 ;
	clk = 1;
	#10 ;
end

initial #1000000 $finish;

initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0,uart_tb);
end

endmodule

