# x0 is hardwired to zero — writes are discarded

    li a0, 1
    addi x0, x0, 5          # attempt to write x0
    bnez x0, fail

    li a0, 2
    li t0, 7
    add zero, t0, t0
    bnez zero, fail

    li a0, 3
    li sp, 0x8000
    li t0, 0x1234
    sw t0, 0(sp)
    lw zero, 0(sp)          # load into x0 is discarded
    bnez zero, fail

    li a0, 4
    lui x0, 0xfffff
    bnez x0, fail

    li a0, 5
    jal x0, next            # jal that writes x0: jump but no link
next:
    bnez x0, fail

    li a0, 6
    li t0, 0
    beqz t0, ok             # x0 still reads as zero in a compare
    j fail
ok:

    li a0, 0
fail:
    ecall
