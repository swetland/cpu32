// Copyright 2012, Brian Swetland.  Use at your own risk.

`define PC_SRC_NEXT	2'b00  // normal
`define PC_SRC_B_IMM	2'b01  // on immediate branches 
`define PC_SRC_B_REG	2'b10  // on indirect branches
`define PC_SRC_X	2'b11  // unspecified

`define W_SRC_ALU	2'b00  // normal
`define W_SRC_RAM	2'b01  // on ram read ops
`define W_SRC_PC_NEXT	2'b10  // on branch link ops
`define W_SRC_X		2'b11  // unspecified

module control (
	input [3:0] opcode,
	input [3:0] opfunc,
	input ctl_adata_zero,
	output ctl_regs_we,
	output ctl_ram_we,
	output ctl_ram_rd,
	output ctl_d_or_b,
	output ctl_imm16,
	output reg [1:0] ctl_pc_src,
	output reg [1:0] ctl_wdata_src,
	output [3:0] ctl_alu_func
	);

reg ctl_branch;

wire ctl_branch_op;
wire ctl_branch_ind;
wire ctl_ram_op;
wire ctl_regs_we_;

reg [7:0] control;

always @ (*)
	case (opcode)
	4'b0000: control = 8'b01000000; // ALU Rd, Ra, Rb
	4'b0001: control = 8'b01001100; // ALU Rd, Ra, #I
	4'b0010: control = 8'b01101100; // LW Rd, [Ra, #]
	4'b0011: control = 8'b00010100; // SW Rd, [Ra, #]
	4'b0100: control = 8'b10001100; // B* rel16
	4'b0101: control = 8'b10000100; // B* Rb
	4'b0110: control = 8'b00000000;
	4'b0111: control = 8'b00000000;
	4'b1000: control = 8'b00000000;
	4'b1001: control = 8'b00000000;
	4'b1010: control = 8'b00000000;
	4'b1011: control = 8'b00000000;
	4'b1100: control = 8'b00000000;
	4'b1101: control = 8'b00000000;
	4'b1110: control = 8'b00000000;
	4'b1111: control = 8'b00000000;
	endcase

assign { ctl_branch_op, ctl_regs_we_, ctl_ram_rd, ctl_ram_we, ctl_d_or_b, ctl_imm16 } = control[7:2];

wire ctl_cond_z;
wire ctl_cond_nz;
wire ctl_link_bit;

assign ctl_cond_z = opfunc[0];
assign ctl_cond_nz = opfunc[1];
assign ctl_link_bit = opfunc[3]; 
assign ctl_branch_ind = opcode[0];

always @ (*)
	case ( { ctl_branch_op, ctl_cond_z, ctl_cond_nz, ctl_adata_zero } )
	4'b1110: ctl_branch = 1'b1;
	4'b1111: ctl_branch = 1'b1;
	4'b1101: ctl_branch = 1'b1;
	4'b1010: ctl_branch = 1'b1;
	default: ctl_branch = 1'b0;
	endcase

always @ (*)
	case ( { ctl_branch, ctl_branch_ind } )
	2'b00: ctl_pc_src = `PC_SRC_NEXT;
	2'b01: ctl_pc_src = `PC_SRC_NEXT;
	2'b10: ctl_pc_src = `PC_SRC_B_IMM;
	2'b11: ctl_pc_src = `PC_SRC_B_REG;
	endcase

always @ (*)
	case ( { ctl_branch, ctl_ram_rd } )
	2'b00: ctl_wdata_src = `W_SRC_ALU;
	2'b01: ctl_wdata_src = `W_SRC_RAM;
	2'b10: ctl_wdata_src = `W_SRC_PC_NEXT;
	2'b11: ctl_wdata_src = `W_SRC_PC_NEXT;
	endcase

assign ctl_alu_func = (ctl_ram_rd | ctl_ram_we) ? 4'b0010 : opfunc;

assign ctl_regs_we = ctl_regs_we_ | (ctl_branch & ctl_link_bit);

endmodule

