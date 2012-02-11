// Copyright 2012, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns
module control (
	input [3:0] opcode,
	input [3:0] opfunc,
	input ctl_adata_zero,		// 1=(adata==0)

	output ctl_alu_pc,		// 0=adata, 1=pc+4 -> alu.left
	output ctl_alu_imm,		// 0=bdata, 1=signed_imm16
	output ctl_regs_we,		// 1=write to reg file
	output ctl_ram_we,		// 1=write to ram
	output ctl_alu_altdest,		// 0=alu.daddr=opd, 1=alu.daddr=opb
	output [1:0] ctl_wdata_src,	// 00=alu,01=ram,10=pc+4,11=0

	output ctl_branch_ind,	// 0=relative branch, 1=indirect branch
	output ctl_branch_taken	// 0=pc=pc+4, 1=pc=branch_to
	);

wire ctl_branch_op;
wire ctl_branch_nz;

reg [7:0] control;

always @ (*)
	case (opcode)
	4'b0000: control = 8'b00100000; // ALU Rd, Ra, Rb
	4'b0001: control = 8'b01101000; // ALU Rd, Ra, #I
	4'b0010: control = 8'b01101001; // LW Rd, [Ra, #I]
	4'b0011: control = 8'b01010000; // SW Rd, [Ra, #I]
	4'b0100: control = 8'b10101110; // B rel16
	4'b0101: control = 8'b10100110; // B Rb
	default: control = 8'b00000000;
	endcase

assign {
	ctl_alu_pc, ctl_alu_imm, ctl_regs_we, ctl_ram_we, 
	ctl_alu_altdest, ctl_branch_op, ctl_wdata_src
	} = control[7:0];

assign ctl_branch_nz = opfunc[3];
assign ctl_branch_ind = opcode[0];
assign ctl_branch_taken = (ctl_branch_op & (ctl_adata_zero != ctl_branch_nz));

endmodule

