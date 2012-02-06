	NOP
	MOV R0, 0xAA
	MOV R14, 0xF0000000
	SW R0, [R15]
	B loop

big:
	MOV R9, 0xE0000000
	MOV R8, 0x34
	SW R8, [R9]

	ADD R0, R0, 1
	SW R0, [R1]
	MOV R2, 5000000
little:
	SUB R2, R2, 1
	BNZ R2, little
	B big

loop:
	MOV R0, 0x34
	BL dputc
	MOV R0, 0x32
	BL dputc
	MOV R0, 10
	BL dputc
	B loop

dputc:
	MOV R1, 0xE0000000
wait:
	LW R2, [R1]
	BNZ R2, wait
	SW R0, [R1]
	B R15

