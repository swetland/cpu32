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

always @(posedge clk)
	count <= count + 1;

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
	
//assign status = count[31:16];
assign status = d_addr[15:0];

wire [31:0] romaddr, romdata;
wire [31:0] d_addr, d_data_r, d_data_w;
wire d_we;

videoram #(8,11) vram(
	.clk(clk),
	.we(d_we && (d_addr[31:16] == 16'hA000)),
	.rdata(vram_data),
	.raddr(vram_addr),
	.wdata(d_data_w[7:0]),
	.waddr(d_addr[13:2]),
	);

rom rom(
	.addr(romaddr[9:2]),
	.data(romdata)
	);

syncram #(32,8) ram(
	.clk(clk),
	.addr(d_addr[9:2]),
	.rdata(d_data_r),
	.wdata(d_data_w),
	.we(d_we && (d_addr[31:10] == 21'b0))
	);

cpu32 cpu(
	.clk(clk),
	.reset(1'b0),
	.i_addr(romaddr),
	.i_data(romdata),
	.d_data_r(d_data_r),
	.d_data_w(d_data_w),
	.d_addr(d_addr),
	.d_data_we(d_we)
	);

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

module rom(
	input [7:0] addr,
	output [31:0] data
	);
reg [31:0] rom[0:2**7];
initial $readmemh("fw.txt", rom);
assign data = rom[addr];
endmodule

