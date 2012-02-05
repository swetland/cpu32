# Copyright 2012, Brian Swetland.  Use at your own risk.

SRC := verilog/testbench.v
SRC += verilog/ram.v verilog/rom.v
SRC += verilog/cpu32.v verilog/alu.v verilog/regfile.v
SRC += verilog/library.v

all: a32 testbench

TESTS := $(wildcard tests/*.s)
RESULTS := $(TESTS:.s=.s.pass)

testbench: $(SRC) 
	iverilog -o testbench $(SRC)

a32: a32.c
	gcc -g -Wall -o a32 a32.c

clean::
	rm -f testbench testbench.vcd a32 rom.txt
	rm -rf tests/*.out tests/*.txt tests/*.trace tests/*.pass

tests/%.s.pass: tests/%.s
	@./runtest.sh $<
	@touch $@

tests:: a32 testbench $(RESULTS)
