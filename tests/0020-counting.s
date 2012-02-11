MOV R0, 0
loop:
ADD R0, R0, 1
SUB R1, R0, 10
BNZ R1, loop
WORD 0xffffffff
