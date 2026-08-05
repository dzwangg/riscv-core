# sh / lh / lhu — both halfword lanes, sign extension

    li sp, 0x8000

    li a0, 1
    li t0, 0xffffffff
    sw t0, 0(sp)
    li t1, 0x1234
    sh t1, 0(sp)            # low half
    li t1, 0x5678
    sh t1, 2(sp)            # high half
    lw t2, 0(sp)
    li t3, 0x56781234
    bne t2, t3, fail

    li a0, 2
    li t0, 0x8000f234
    sw t0, 4(sp)
    lhu t1, 4(sp)           # zero-extend low half
    li t2, 0xf234
    bne t1, t2, fail

    li a0, 3
    lhu t1, 6(sp)           # zero-extend high half
    li t2, 0x8000
    bne t1, t2, fail

    li a0, 4
    lh t1, 4(sp)            # sign-extend 0xf234
    li t2, 0xfffff234
    bne t1, t2, fail

    li a0, 5
    lh t1, 6(sp)            # sign-extend 0x8000
    li t2, 0xffff8000
    bne t1, t2, fail

    li a0, 6
    li t0, 0x7abc
    sh t0, 8(sp)
    lh t1, 8(sp)            # positive halfword unchanged
    li t2, 0x7abc
    bne t1, t2, fail

    # sh only writes the low 16 bits of the source
    li a0, 7
    li t0, 0xdead1234
    sh t0, 12(sp)
    lhu t1, 12(sp)
    li t2, 0x1234
    bne t1, t2, fail

    li a0, 0
fail:
    ecall
