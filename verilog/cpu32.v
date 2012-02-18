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
	output d_data_we
	);

reg sync_reset;

always @(posedge clk)
	if (reset)
		sync_reset <= 1'b1;
	else
		sync_reset <= 1'b0;

wire [31:0] pc;
reg [31:0] ir;

wire [31:0] next_pc, pc_plus_4, next_pc0;

wire [3:0] opcode, opfunc, opsela, opselb, opseld;
wire [15:0] opimm16;

wire [31:0] adata, bdata, wdata, result;

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
wire ctl_wdata_ram;
wire ctl_branch_ind;
wire ctl_branch_taken;

control control(
	.opcode(opcode),
	.opfunc(opfunc),
	.ctl_adata_zero(ctl_adata_zero),
	.hazard(hazard_rrw),

	.ctl_alu_pc(ctl_alu_pc),
	.ctl_alu_imm(ctl_alu_imm),
	.ctl_regs_we(ctl_regs_we),
	.ctl_ram_we(ctl_ram_we),
	.ctl_alu_altdest(ctl_alu_altdest),
	.ctl_wdata_ram(ctl_wdata_ram),

	.ctl_branch_ind(ctl_branch_ind),
	.ctl_branch_taken(ctl_branch_taken)
	);

wire ctl_adata_zero;
assign ctl_adata_zero = (adata == 32'h0);

register #(32) PC (
	.clk(clk),
	.reset(sync_reset),
	.en(1), 
	.din(next_pc),
	.dout(pc)
	);

assign i_addr = next_pc;

always @(posedge clk)
	if (sync_reset) begin
		ir <= 32'hEEEE7777;
	end else begin
		if (!hazard_rrw)
			ir <= i_data;
	end

/* these arrive from writeback */
wire [31:0] regs_wdata;
wire [3:0] regs_wsel;
wire regs_we;

regfile REGS (
	.reset(reset),
	.clk(clk),
	.we(regs_we),
	.wsel(regs_wsel), .wdata(regs_wdata),
	.asel(opsela), .adata(adata),
	.bsel(opselb), .bdata(bdata)
	);

// attempt to identify hazards
wire hazard1, hazard2, hazard_rrw;
assign hazard1 = (((regs_wsel == opsela) | (regs_wsel == opselb)) & regs_we) & (regs_wsel != 4'b1111);
assign hazard2 = (((mem_wsel == opsela) | (mem_wsel == opselb)) & mem_we) & (mem_wsel != 4'b1111);
assign hazard_rrw = hazard1 | hazard2;

assign pc_plus_4 = hazard_rrw ? pc : (pc + 32'h4);

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
	.out(next_pc0)
	);

mux2 #(32) mux_next_pc(
	.sel(sync_reset),
	.in0(next_pc0),
	.in1(32'h0),
	.out(next_pc)
	);

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

wire [3:0] ctl_wsel;

mux2 #(4) alu_wsel_mux(
	.sel(ctl_alu_altdest),
	.in0(opseld),
	.in1(opselb),
	.out(ctl_wsel)
	);

alu alu(
	.opcode(opfunc),
	.left(ainput),
	.right(binput),
	.out(result)
	);

wire [31:0] mem_data;
wire [3:0] mem_wsel;
wire mem_we;

memory mem(
	.clk(clk),
	.reset(reset),

	.in_alu_data(result),
	.in_reg_data(bdata),

	.in_mem_we(ctl_ram_we),
	.in_regs_we(ctl_regs_we),
	.in_regs_wsel(ctl_wsel),
	.in_wdata_ram(ctl_wdata_ram),

	.out_data(mem_data),
	.out_wsel(mem_wsel),
	.out_we(mem_we),

	.d_addr(d_addr),
	.d_data_r(d_data_r),
	.d_data_w(d_data_w),
	.d_data_we(d_data_we)
	);

writeback wb(
	.clk(clk),
	.reset(reset),

	.in_data(mem_data),
	.in_wsel(mem_wsel),
	.in_we(mem_we),

	.out_we(regs_we),
	.out_wsel(regs_wsel),
	.out_data(regs_wdata)
	);

endmodule


module memory(
	input clk,
	input reset,

	/* interface to sync sram */
	output [31:0] d_addr,
	input  [31:0] d_data_r,
	output [31:0] d_data_w,
	output d_data_we,

	/* interface to processor core */
	input [31:0] in_alu_data,
	input [31:0] in_reg_data,

	input in_mem_we,
	input in_regs_we,
	input [3:0] in_regs_wsel,
	input in_wdata_ram,

	output [31:0] out_data,
	output [3:0] out_wsel,
	output out_we
	);

	reg [31:0] alu_data;
	reg [31:0] reg_data;
	reg mem_we;
	reg regs_we;
	reg [3:0] regs_wsel;
	reg wdata_ram;

	always @(posedge clk) begin
		if (reset) begin
			alu_data <= 32'b0;
			reg_data <= 32'b0;
			mem_we <= 1'b0;
			regs_we <= 1'b0;
			regs_wsel <= 4'b0;
			wdata_ram <= 1'b0;
		end else begin
			alu_data <= in_alu_data;
			reg_data <= in_reg_data;
			mem_we <= in_mem_we;
			regs_we <= in_regs_we;
			regs_wsel <= in_regs_wsel;
			wdata_ram <= in_wdata_ram;
		end
	end

	assign d_addr = in_alu_data; 
	assign d_data_w = in_reg_data;
	assign d_data_we = in_mem_we;

	mux2 #(32) mux_data(
		.sel(wdata_ram),
		.in0(alu_data),
		.in1(d_data_r),
		.out(out_data)
		);

	assign out_wsel = regs_wsel;
	assign out_we = regs_we;
endmodule

module writeback(
	input clk,
	input reset,

	input [31:0] in_data,
	input [3:0] in_wsel,
	input in_we,

	output out_we,
	output [3:0] out_wsel,
	output [31:0] out_data
	);

	reg [31:0] data;
	reg [3:0] wsel;
	reg we;

	always @(posedge clk) begin
		if (reset) begin
			data <= 32'b0;
			wsel <= 4'b0;
			we <= 1'b0;
		end else begin
			data <= in_data;
			wsel <= in_wsel;
			we <= in_we;
		end
	end

	assign out_we = we;
	assign out_wsel = wsel;
	assign out_data = data;
endmodule

	
	
