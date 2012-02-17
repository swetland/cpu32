// Copyright 2012, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns
module control (
	input [3:0] opcode,
	input [3:0] opfunc,
	input ctl_adata_zero,		// 1=(adata==0)
	input hazard,

	output ctl_alu_pc,		// 0=adata, 1=pc+4 -> alu.left
	output ctl_alu_imm,		// 0=bdata, 1=signed_imm16
	output ctl_regs_we,		// 1=write to reg file
	output ctl_ram_we,		// 1=write to ram
	output ctl_alu_altdest,		// 0=alu.daddr=opd, 1=alu.daddr=opb
	output ctl_wdata_ram,		// 0=alu, 1=ram

	output ctl_branch_ind,	// 0=relative branch, 1=indirect branch
	output ctl_branch_taken	// 0=pc=pc+4, 1=pc=branch_to
	);

wire ctl_branch_op;
wire ctl_branch_nz;

reg [6:0] control;

always @ (*) begin
	case (opcode)
	4'b0000: control = 7'b0010000; // ALU Rd, Ra, Rb
	4'b0001: control = 7'b0110100; // ALU Rd, Ra, #I
	4'b0010: control = 7'b0110101; // LW Rd, [Ra, #I]
	4'b0011: control = 7'b0101000; // SW Rd, [Ra, #I]
	4'b0100: control = 7'b1010110; // BLZ rel16
	4'b0101: control = 7'b1010110; // BLNZ rel16
	4'b0110: control = 7'b1010010; // BLZ Rb
	4'b0111: control = 7'b1010010; // BLNZ Rb
	4'b1110: control = 7'b1100000; // NOP
	default: control = 7'b0000000;
	endcase

	if (hazard) control = 7'b1100000;
end

assign {
	ctl_alu_pc, ctl_alu_imm, ctl_regs_we, ctl_ram_we, 
	ctl_alu_altdest, ctl_branch_op, ctl_wdata_ram
	} = control;

assign ctl_branch_nz = opcode[0];
assign ctl_branch_ind = opcode[1];
assign ctl_branch_taken = (ctl_branch_op & (ctl_adata_zero != ctl_branch_nz));

endmodule

