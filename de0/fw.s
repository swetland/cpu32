nop
mov	r0, 65
again:
mov	r1, 2048
mov	r9, 0xA0000000
nop
nop
loop:
sw	r0, [r9]
add	r9, r9, 4
sub	r1, r1, 1
nop
nop
bnz	r1, loop

mov	r5, 0x00100000
nop
nop
loopz:
sub	r5, r5, 1
nop
nop
bnz	r5, loopz

add	r0, r0, 1
nop
nop
and	r0, r0, 127
nop
nop
b	again

