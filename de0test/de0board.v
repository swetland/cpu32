// Copyright 2012, Brian Swetland

module de0board(
	input CLOCK_50,
	output [9:0] LEDG,
	output [6:0] HEX0_D,
	output [6:0] HEX1_D,
	output [6:0] HEX2_D,
	output [6:0] HEX3_D,
	output HEX0_DP,
	output HEX1_DP,
	output HEX2_DP,
	output HEX3_DP,
	output [3:0] VGA_R,
	output [3:0] VGA_G,
	output [3:0] VGA_B,
	output VGA_HS,
	output VGA_VS
	);

wire [15:0] status;
reg [31:0] count;

assign LEDG = 10'b1111111111;
assign HEX0_DP = 1'b1;
assign HEX1_DP = 1'b1;
assign HEX2_DP = 1'b1;
assign HEX3_DP = 1'b1;

hex2seven hex0(.in(status[3:0]),.out(HEX0_D));
hex2seven hex1(.in(status[7:4]),.out(HEX1_D));
hex2seven hex2(.in(status[11:8]),.out(HEX2_D));
hex2seven hex3(.in(status[15:12]),.out(HEX3_D));

wire clk;
assign clk = CLOCK_50;

reg clk25;

always @(posedge clk)
	clk25 = ~clk25;

wire newline, advance;
wire [11:0] pixel;
wire [10:0] vram_addr;
wire [7:0] vram_data;
wire [7:0] line;

vga vga(
	.clk(clk25),
	.reset(1'b0),
	.newline(newline),
	.advance(advance),
	.line(line),
	.pixel(pixel),
	.r(VGA_R),
	.b(VGA_B),
	.g(VGA_G),
	.hs(VGA_HS),
	.vs(VGA_VS)
	);

pixeldata pxd(
	.clk(clk25),
	.newline(newline),
	.advance(advance),
	.line(line),
	.pixel(pixel),
	.vram_data(vram_data),
	.vram_addr(vram_addr)
	);
	
//assign status = 16'h1234;

wire [7:0] wdata;
reg [10:0] waddr;
wire we;

videoram #(8,11) vram(
	.clk(clk),
	.we(we),
	.rdata(vram_data),
	.raddr(vram_addr),
	.wdata(wdata),
	.waddr(waddr)
	);

wire [3:0] iir;
wire tdi, tdo, tck, cdr, sdr, udr, uir;
reg [15:0] dr;
reg [3:0] ir;

jtag jtag0(
	.tdi(tdi),
	.tdo(tdo),
	.tck(tck),
	.ir_in(iir),
	.virtual_state_cdr(cdr),
	.virtual_state_sdr(sdr),
	.virtual_state_udr(udr),
	.virtual_state_uir(uir)
	);

parameter IR_ADDR = 4'h1;
parameter IR_DATA = 4'h2;

always @(posedge tck) begin
	if (uir)
		ir <= iir;
	if (cdr)
		dr <= 16'hABCD;
	if (sdr)
		dr <= { tdi, dr[15:1] };
	end
assign tdo = dr[0];

wire update;

sync sync0(
	.in(udr),
	.clk_in(tck),
	.out(update),
	.clk_out(clk)
	);

assign wdata = dr[7:0];
assign we = update & (ir == IR_DATA);

always @(posedge clk)
	if (update) case (iir)
		IR_ADDR: waddr <= dr[10:0];
		IR_DATA: waddr <= waddr + 11'd1;
	endcase

reg [31:0] dispreg;
assign status = dispreg[15:0];

endmodule

module sync(
	input clk_in,
	input clk_out,
	input in,
	output out
	);
reg toggle;
reg [2:0] sync;
always @(posedge clk_in)
	if (in) toggle <= ~toggle;
always @(posedge clk_out)
	sync <= { sync[1:0], toggle };
assign out = (sync[2] ^ sync[1]);
endmodule


module hex2seven(
	input [3:0] in,
	output reg [6:0] out
	);

always @(*) case (in)
	4'h0: out = 7'b1000000;
	4'h1: out = 7'b1111001;
	4'h2: out = 7'b0100100;
	4'h3: out = 7'b0110000;
	4'h4: out = 7'b0011001;
	4'h5: out = 7'b0010010;
	4'h6: out = 7'b0000011;
	4'h7: out = 7'b1111000;
	4'h8: out = 7'b0000000;
	4'h9: out = 7'b0011000;
	4'hA: out = 7'b0001000;
	4'hB: out = 7'b0000011;
	4'hC: out = 7'b1000110;
	4'hD: out = 7'b0100001;
	4'hE: out = 7'b0000110;
	4'hF: out = 7'b0001110;
endcase

endmodule

