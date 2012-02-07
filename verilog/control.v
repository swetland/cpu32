module control (
	input [3:0] opcode,
	input [3:0] opfunc,
	input ctl_adata_zero,
	output ctl_regs_we,
	output ctl_ram_we,
	output ctl_ram_rd,
	output ctl_d_or_b,
	output ctl_branch,
	output ctl_branch_ind,
	output ctl_ram_op,
	output ctl_imm16,
	output ctl_link_bit,
	output [3:0] ctl_alu_func
	);

// cheesy decoder -- TODO: write for real
assign ctl_regs_we = 
	(opcode[3:1] == 3'h0) ||
	(opcode == 4'h2) ||
	(ctl_branch && ctl_link_bit) ||
	(ctl_branch_ind && ctl_link_bit);
assign ctl_d_or_b = ((opcode == 4'h1) || (opcode == 4'h2) || (opcode == 4'h4));
assign ctl_ram_rd = (opcode == 4'h2);
assign ctl_ram_we = (opcode == 4'h3);
assign ctl_ram_op = ((opcode == 4'h2) || (opcode == 4'h3));
assign ctl_alu_func = ctl_ram_op ? 4'b0010 : opfunc;
assign ctl_imm16 = (opcode != 4'h0);
assign ctl_link_bit = opfunc[3]; 

// branch if it is a branch opcode and the condition is met
// unconditional branches set both condition bits
assign ctl_branch = (opcode == 4'h4) & 
	((opfunc[0] & ctl_adata_zero) || (opfunc[1] & (!ctl_adata_zero)));
assign ctl_branch_ind = (opcode == 4'h5) & 
	((opfunc[0] & ctl_adata_zero) || (opfunc[1] & (!ctl_adata_zero)));

endmodule

