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

wire [31:0] next_pc, pc_adjust;

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

wire ctl_regs_we;  // 1 = write back to register file
wire ctl_d_or_b;   // 0 = write to R[opseld], 1 = R[opselb]
wire ctl_branch;   // 1 = immediate branch
wire ctl_ram_op;
wire ctl_imm16;    // 0 = bdata, 1 = imm16 -> alu right
wire ctl_adata_zero;

wire [3:0] ctl_alu_func;

// cheesy decoder -- TODO: write for real
assign ctl_regs_we = ((opcode[3:1] == 0) || (opcode == 2));
assign ctl_d_or_b = ((opcode == 1) || (opcode == 2));
assign ctl_ram_rd = (opcode == 2);
assign ctl_ram_we = (opcode == 3);
assign ctl_ram_op = ((opcode == 2) || (opcode == 3));
assign ctl_alu_func = ctl_ram_op ? 4'b0010 : opfunc;
assign ctl_imm16 = (opcode != 0);

assign ctl_adata_zero = (adata == 32'h0);

// branch if it is a branch opcode and the condition is met
// unconditional branches set both condition bits
assign ctl_branch = (opcode == 4) & 
	((opfunc[0] & ctl_adata_zero) || (opfunc[1] & (!ctl_adata_zero)));

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

mux2 #(32) wdata_mux(
	.sel(ctl_ram_rd),
	.in0(result),
	.in1(d_data_r),
	.out(wdata)
	);

assign next_pc = pc + pc_adjust;

wire S;
assign S = opimm16[15];

mux2 #(32) pc_source(
	.sel(ctl_branch),
	.in0(4),
	.in1( {S,S,S,S,S,S,S,S,S,S,S,S,S,S,opimm16,2'h0} ),
	.out(pc_adjust)
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
