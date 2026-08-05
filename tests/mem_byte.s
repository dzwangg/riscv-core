# sb / lb / lbu — every byte lane, sign extension, lane isolation

    li sp, 0x8000

    # store one byte in each lane of a known word
    li a0, 1
    li t0, 0xffffffff
    sw t0, 0(sp)
    li t1, 0x11
    sb t1, 0(sp)
    li t1, 0x22
    sb t1, 1(sp)
    li t1, 0x33
    sb t1, 2(sp)
    li t1, 0x44
    sb t1, 3(sp)
    lw t2, 0(sp)
    li t3, 0x44332211
    bne t2, t3, fail

    # sb must not disturb neighboring bytes
    li a0, 2
    li t0, 0xaabbccdd
    sw t0, 4(sp)
    li t1, 0x99
    sb t1, 5(sp)            # only byte 1 changes
    lw t2, 4(sp)
    li t3, 0xaabb99dd
    bne t2, t3, fail

    # lbu: zero-extended from each lane
    li a0, 3
    li t0, 0x80c1d2f3
    sw t0, 8(sp)
    lbu t1, 8(sp)
    li t2, 0xf3
    bne t1, t2, fail
    li a0, 4
    lbu t1, 9(sp)
    li t2, 0xd2
    bne t1, t2, fail
    li a0, 5
    lbu t1, 10(sp)
    li t2, 0xc1
    bne t1, t2, fail
    li a0, 6
    lbu t1, 11(sp)
    li t2, 0x80
    bne t1, t2, fail

    # lb: sign-extended
    li a0, 7
    lb t1, 8(sp)            # 0xf3 -> 0xfffffff3
    li t2, 0xfffffff3
    bne t1, t2, fail
    li a0, 8
    lb t1, 11(sp)           # 0x80 -> 0xffffff80
    li t2, 0xffffff80
    bne t1, t2, fail
    li a0, 9
    li t0, 0x7f
    sb t0, 12(sp)
    lb t1, 12(sp)           # 0x7f stays positive
    li t2, 0x7f
    bne t1, t2, fail

    # sb only writes the low byte of the source register
    li a0, 10
    li t0, 0x12345678
    sb t0, 16(sp)
    lbu t1, 16(sp)
    li t2, 0x78
    bne t1, t2, fail

    li a0, 0
fail:
    ecall
