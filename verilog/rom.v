// ROM
//
// Copyright 2009, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns

module rom #(parameter DWIDTH=16, parameter AWIDTH=8) (
	input [AWIDTH-1:0] addr,
	output [DWIDTH-1:0] data
	);

	reg [DWIDTH-1:0] rom[0:2**AWIDTH-1];

	reg [256:0] romfile;

	initial
		if ($value$plusargs("ROM=%s",romfile))
			$readmemh(romfile, rom);
		else
			$readmemh("rom.txt", rom);

	assign data = rom[addr];
endmodule

				   
		  
