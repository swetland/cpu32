	MOV R0, 0x11223344
	MOV R1, 0x74
	SW R0, [R1]
	MOV R2, 0x77777777
	LW R3, [R1]
	ADD R11, R3, R0
	NOP
	WORD 0xFFFFFFFF