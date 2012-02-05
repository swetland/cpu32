MOV R0, 0
loop:
ADD R0, R0, 1
SEQ R1, R0, 10
BZ R1, loop
WORD 0xffffffff
