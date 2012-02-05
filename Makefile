# Copyright 2012, Brian Swetland.  Use at your own risk.

SRC := verilog/testbench.v
SRC += verilog/ram.v verilog/rom.v
SRC += verilog/cpu32.v verilog/alu.v verilog/regfile.v
SRC += verilog/library.v

all: a32 testbench

testbench: $(SRC) rom.txt
	iverilog -o testbench $(SRC)

rom.txt: rom.s
	./a32 rom.s rom.txt

a32: a32.c
	gcc -g -Wall -o a32 a32.c

clean::
	rm -f testbench testbench.vcd a32 rom.txt
