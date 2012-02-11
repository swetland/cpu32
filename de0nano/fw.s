	NOP
	MOV	R12, 0xF0000000
	MOV	R11, 0xE0000000

	MOV	R0, 0x30
	BL	uart_send
	MOV	R0, 0x31
	BL	uart_send
	MOV	R0, 0x32
	BL	uart_send
	MOV	R0, 0x33
	BL	uart_send

	MOV	R0, 0
	MOV	R2, 256
xmit_loop:
	SW	R0, [R12]
wait_fifo:
	LW	R1, [R11]
	BNZ	R1, wait_fifo
	SW	R0, [R11]
	ADD	R0, R0, 1
	SUB	R2, R2, 1
	BNZ	R2, xmit_loop

	MOV	R0, 0
	SW	R0, [R12]
	B	.


uart_send:
	MOV	R11, 0xE0000000
uart_wait:
	LW	R12, [R11]
	BNZ	R12, uart_wait
	SW	R0, [R11]
	B	LR
