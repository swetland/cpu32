// CPU32 Non-pipelined Core
//
// Copyright 2012, Brian Swetland.  Use at your own risk.

module cpu32 (
	input clk,
	output [31:0] i_addr,
	input [31:0] i_data,
	output [31:0] d_addr,
	output [31:0] d_data_w,
	input [31:0] d_data_r,
	output d_we
	);

wire [31:0] ir, pc;

wire [31:0] next_pc, pc_plus_4;

wire [3:0] opcode, opfunc, opsela, opselb, opseld;
wire [15:0] opimm16;

wire [31:0] adata, bdata, wdata, result;
wire [3:0] alu_wsel;

assign opcode = ir[31:28];
assign opfunc = ir[27:24];
assign opsela = ir[23:20];
assign opselb = ir[19:16];
assign opseld = ir[15:12];
assign opimm16 = ir[15:0];

wire ctl_regs_we;    // 1 = write back to register file
wire ctl_d_or_b;     // 0 = write to R[opseld], 1 = R[opselb]
wire ctl_branch;     // 1 = direct branch
wire ctl_branch_ind; // 1 = indirect branch
wire ctl_link_bit;   // 1 if the link bit is set (only for branches)
wire ctl_ram_op;
wire ctl_imm16;      // 0 = bdata, 1 = imm16 -> alu right
wire [3:0] ctl_alu_func;
wire ctl_ram_we;
wire ctl_ram_rd;

control control(
	.opcode(opcode),
	.opfunc(opfunc),
	.ctl_adata_zero(ctl_adata_zero),
	.ctl_regs_we(ctl_regs_we),
	.ctl_d_or_b(ctl_d_or_b),
	.ctl_branch(ctl_branch),
	.ctl_branch_ind(ctl_branch_ind),
	.ctl_ram_op(ctl_ram_op),
	.ctl_imm16(ctl_imm16),
	.ctl_ram_we(ctl_ram_we),
	.ctl_ram_rd(ctl_ram_rd),
	.ctl_link_bit(ctl_link_bit),
	.ctl_alu_func(ctl_alu_func)
	);

wire ctl_adata_zero;
assign ctl_adata_zero = (adata == 32'h0);

register #(32) PC (
	.clk(clk),
	.en(1),
	.din(next_pc),
	.dout(pc)
	);

regfile #(32,4) REGS (
	.clk(clk),
	.we(ctl_regs_we),
	.wsel(alu_wsel), .wdata(wdata),
	.asel(opsela), .adata(adata),
	.bsel(opselb), .bdata(bdata)
	);

mux4 #(32) wdata_mux(
	.sel({ctl_branch,ctl_ram_rd}),
	.in0(result),
	.in1(d_data_r),
	.in2(pc_plus_4),
	.in3(pc_plus_4),
	.out(wdata)
	);

assign pc_plus_4 = (pc + 32'h4);

wire S;
assign S = opimm16[15];

mux4 #(32) pc_source(
	.sel({ctl_branch_ind,ctl_branch}),
	.in0(pc_plus_4),
	.in1(pc + {S,S,S,S,S,S,S,S,S,S,S,S,S,S,opimm16,2'h0} ),
	.in2(bdata),
	.in3(bdata),
	.out(next_pc)
	);

assign i_addr = pc;
assign ir = i_data;

wire [31:0] binput;

mux2 #(32) alu_right_mux(
		.sel(ctl_imm16),
		.in0(bdata),
		.in1({ 16'h0, opimm16 }),
		.out(binput)
	);

mux2 #(4) alu_wsel_mux(
		.sel(ctl_d_or_b),
		.in0(opseld),
		.in1(opselb),
		.out(alu_wsel)
	);

alu alu(
	.opcode(ctl_alu_func),
	.left(adata),
	.right(binput),
	.out(result)
	);

// SW operation always writes Rb (aka Rd)
assign d_addr = result;
assign d_data_w = bdata;
assign d_we = ctl_ram_we;

endmodule
