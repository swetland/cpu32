module de0nano(
	input  CLOCK_50,
	output [7:0] LED,
	input  [1:0] KEY,
	input  [3:0] SW,

	output [12:0] DRAM_ADDR,
	output [1:0] DRAM_BA,
	output DRAM_CAS_N,
	output DRAM_CKE,
	output DRAM_CLK,
	output DRAM_CS_N,
	inout  [15:0] DRAM_DQ,
	output [1:0] DRAM_DQM,
	output DRAM_RAS_N,
	output DRAM_WE_N,

	output I2C_SCLK,
	inout  I2C_SDAT,

	inout [12:0] GPIO_2,
	input [2:0] GPIO_2_IN,

	inout [11:0] GPIO_A	
);

wire clk, reset;
wire [31:0] romaddr, romdata, ramaddr, ramrdata, ramwdata;
wire [31:0] uartrdata;
wire cpurdata;
wire ramwe;
wire cs0,cs1;

assign cs0 = (ramaddr[31:16] == 16'h0000);
assign cs1 = (ramaddr[31:16] == 16'hE000);

reg [3:0] cntr;

always @(posedge CLOCK_50)
	cntr <= cntr + 4'b0001;
	
//assign clk = CLOCK_50;
assign clk = cntr[3];

cpu32 cpu(
        .clk(clk),
        .i_addr(romaddr),
        .i_data(romdata),
        .d_data_r(cpurdata),
        .d_data_w(ramwdata),
        .d_addr(ramaddr),
        .d_we(ramwe)
        );

// ugly hack for now
mux2 #(32) rdatamux(
	.sel(cs1),
	.in0(ramrdata),
	.in1({24'b0,uartrdata}),
	.out(cpurdata)
	);
	
rom rom(
        .addr(romaddr[9:2]),
        .data(romdata)
        );

aram ram(
	.clock(clk),
	.address(ramaddr[10:2]),
	.data(ramwdata),
	.q(ramrdata),
	.wren(cs0 & ramwe)
);

assign GPIO_A[1] = bclk;
assign GPIO_A[3] = uartrdata[0];

uart uart0(
	.clk(clk),
	.bclk(bclk),
	.reset(0),
	.we(cs1 & ramwe),
	.wdata(ramwdata),
	.rdata(uartrdata[7:0]),
	.tx(GPIO_A[7])
	);

reg [8:0] bcnt;
reg bclk;

always @(posedge CLOCK_50)
	if (bcnt == 217) begin
			bcnt <= 0;
			bclk = ~bclk;
	end else begin
			bcnt = bcnt + 1;
	end

reg [7:0] DBG;
assign LED = DBG;

always @(posedge clk)
	if (ramwe && (ramaddr == 32'hF0000000))
		DBG <= ramwdata[7:0];

endmodule

module rom(
	input [7:0] addr,
	output [31:0] data
	);
reg [31:0] rom[0:2**7];
initial $readmemh("fw.txt", rom);
assign data = rom[addr];
endmodule
