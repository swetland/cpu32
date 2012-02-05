# Copyright 2012, Brian Swetland.  Use at your own risk.

SRC := testbench.v cpu32.v alu.v ram.v rom.v regfile.v library.v

all: a32 testbench

testbench: $(SRC) rom.txt
	iverilog -o testbench $(SRC)

rom.txt: rom.asm
	./a32 rom.asm rom.txt

a32: a32.c
	gcc -g -Wall -o a32 a32.c

clean::
	rm -f testbench testbench.vcd a32 rom.txt
