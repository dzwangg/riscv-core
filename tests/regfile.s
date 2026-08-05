# every register x1..x29 holds a distinct value simultaneously (catches a
# register file that aliases indices, e.g. dropping bit 4), and a barrage of
# branches must not write any register (branch rd bits encode the immediate).
# x10 (a0) is the case number; x30/x31 are scratch.

    li x1,  0x101
    li x2,  0x202
    li x3,  0x303
    li x4,  0x404
    li x5,  0x505
    li x6,  0x606
    li x7,  0x707
    li x8,  0x808
    li x9,  0x909
    li x11, 0xb0b
    li x12, 0xc0c
    li x13, 0xd0d
    li x14, 0xe0e
    li x15, 0xf0f
    li x16, 0x1010
    li x17, 0x1111
    li x18, 0x1212
    li x19, 0x1313
    li x20, 0x1414
    li x21, 0x1515
    li x22, 0x1616
    li x23, 0x1717
    li x24, 0x1818
    li x25, 0x1919
    li x26, 0x1a1a
    li x27, 0x1b1b
    li x28, 0x1c1c
    li x29, 0x1d1d

    jal x31, checkall       # first pass: everything landed intact

    # branches with varied offsets/directions, taken and not taken
    li a0, 60
    beq x0, x0, bc1         # taken forward
    j fail
bc1:
    bne x5, x5, fail        # not taken
    blt x0, x5, bc2         # taken forward
    j fail
bc2:
    bgeu x0, x5, fail       # not taken
    j bc4
bc3:
    j bc5
bc4:
    beq x0, x0, bc3         # taken backward
bc5:

    jal x31, checkall       # second pass: branches must not have clobbered anything

    li a0, 0
    ecall

# verifies all 28 filled registers; call with jal x31, returns via x31
checkall:
    li a0, 21
    li x30, 0x101
    bne x1, x30, fail
    li a0, 22
    li x30, 0x202
    bne x2, x30, fail
    li a0, 23
    li x30, 0x303
    bne x3, x30, fail
    li a0, 24
    li x30, 0x404
    bne x4, x30, fail
    li a0, 25
    li x30, 0x505
    bne x5, x30, fail
    li a0, 26
    li x30, 0x606
    bne x6, x30, fail
    li a0, 27
    li x30, 0x707
    bne x7, x30, fail
    li a0, 28
    li x30, 0x808
    bne x8, x30, fail
    li a0, 29
    li x30, 0x909
    bne x9, x30, fail
    li a0, 31
    li x30, 0xb0b
    bne x11, x30, fail
    li a0, 32
    li x30, 0xc0c
    bne x12, x30, fail
    li a0, 33
    li x30, 0xd0d
    bne x13, x30, fail
    li a0, 34
    li x30, 0xe0e
    bne x14, x30, fail
    li a0, 35
    li x30, 0xf0f
    bne x15, x30, fail
    li a0, 36
    li x30, 0x1010
    bne x16, x30, fail
    li a0, 37
    li x30, 0x1111
    bne x17, x30, fail
    li a0, 38
    li x30, 0x1212
    bne x18, x30, fail
    li a0, 39
    li x30, 0x1313
    bne x19, x30, fail
    li a0, 40
    li x30, 0x1414
    bne x20, x30, fail
    li a0, 41
    li x30, 0x1515
    bne x21, x30, fail
    li a0, 42
    li x30, 0x1616
    bne x22, x30, fail
    li a0, 43
    li x30, 0x1717
    bne x23, x30, fail
    li a0, 44
    li x30, 0x1818
    bne x24, x30, fail
    li a0, 45
    li x30, 0x1919
    bne x25, x30, fail
    li a0, 46
    li x30, 0x1a1a
    bne x26, x30, fail
    li a0, 47
    li x30, 0x1b1b
    bne x27, x30, fail
    li a0, 48
    li x30, 0x1c1c
    bne x28, x30, fail
    li a0, 49
    li x30, 0x1d1d
    bne x29, x30, fail
    jalr x0, 0(x31)

fail:
    ecall
