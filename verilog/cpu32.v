// CPU32 Non-pipelined Core
//
// Copyright 2012, Brian Swetland.  Use at your own risk.

`timescale 1ns/1ns

module cpu32 (
	input clk,
	input reset,
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

wire [31:0] opimm16s;
assign opimm16s[31:0] = { {16{opimm16[15]}} , opimm16[15:0] };

wire ctl_alu_pc;
wire ctl_alu_imm;
wire ctl_regs_we;
wire ctl_ram_we;
wire ctl_alu_altdest;
wire [1:0] ctl_wdata_src;
wire ctl_branch_ind;
wire ctl_branch_taken;

control control(
	.opcode(opcode),
	.opfunc(opfunc),
	.ctl_adata_zero(ctl_adata_zero),

	.ctl_alu_pc(ctl_alu_pc),
	.ctl_alu_imm(ctl_alu_imm),
	.ctl_regs_we(ctl_regs_we),
	.ctl_ram_we(ctl_ram_we),
	.ctl_alu_altdest(ctl_alu_altdest),
	.ctl_wdata_src(ctl_wdata_src),

	.ctl_branch_ind(ctl_branch_ind),
	.ctl_branch_taken(ctl_branch_taken)
	);

wire ctl_adata_zero;
assign ctl_adata_zero = (adata == 32'h0);

register #(32) PC (
	.clk(clk),
	.reset(reset),
	.en(1),
	.din(next_pc),
	.dout(pc)
	);

regfile REGS (
	.reset(reset),
	.clk(clk),
	.we(ctl_regs_we),
	.wsel(alu_wsel), .wdata(wdata),
	.asel(opsela), .adata(adata),
	.bsel(opselb), .bdata(bdata)
	);

mux4 #(32) mux_wdata_src(
	.sel(ctl_wdata_src),
	.in0(result),
	.in1(d_data_r),
	.in2(pc_plus_4),
	.in3(32'b0),
	.out(wdata)
	);

assign pc_plus_4 = (pc + 32'h4);

wire [31:0] branch_to;
mux2 #(32) mux_branch_to(
	.sel(ctl_branch_ind),
	.in0(pc + { opimm16s[29:0], 2'b00 } ),
	.in1(bdata),
	.out(branch_to)
	);

mux2 #(32) mux_pc_source(
	.sel(ctl_branch_taken),
	.in0(pc_plus_4),
	.in1(branch_to),
	.out(next_pc)
	);

assign i_addr = pc;
assign ir = i_data;

wire [31:0] ainput;
wire [31:0] binput;

mux2 #(32) mux_alu_left(
	.sel(ctl_alu_pc),
	.in0(adata),
	.in1(pc_plus_4),
	.out(ainput)
	);

mux2 #(32) mux_alu_right(
	.sel(ctl_alu_imm),
	.in0(bdata),
	.in1(opimm16s),
	.out(binput)
	);

mux2 #(4) alu_wsel_mux(
	.sel(ctl_alu_altdest),
	.in0(opseld),
	.in1(opselb),
	.out(alu_wsel)
	);

alu alu(
	.opcode(opfunc),
	.left(ainput),
	.right(binput),
	.out(result)
	);

// SW operation always writes Rb (aka Rd)
assign d_addr = result;
assign d_data_w = bdata;
assign d_we = ctl_ram_we;

endmodule
