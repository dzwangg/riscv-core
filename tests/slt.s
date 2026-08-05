# slt / sltu / slti / sltiu — signed vs unsigned edge cases

    li a0, 1
    li t0, -1
    li t1, 1
    slt t2, t0, t1          # signed: -1 < 1
    li t3, 1
    bne t2, t3, fail

    li a0, 2
    sltu t2, t0, t1         # unsigned: 0xffffffff > 1
    bnez t2, fail

    li a0, 3
    li t0, 0x80000000
    li t1, 1
    slt t2, t0, t1          # most negative < 1
    li t3, 1
    bne t2, t3, fail

    li a0, 4
    sltu t2, t1, t0         # unsigned: 1 < 0x80000000
    li t3, 1
    bne t2, t3, fail

    li a0, 5
    li t0, 5
    slt t2, t0, t0          # x < x is false
    bnez t2, fail

    li a0, 6
    li t0, -5
    slti t2, t0, -4         # -5 < -4
    li t3, 1
    bne t2, t3, fail

    li a0, 7
    slti t2, t0, -6         # -5 < -6 is false
    bnez t2, fail

    li a0, 8
    li t0, 3
    sltiu t2, t0, -1        # imm sign-extends to 0xffffffff; 3 < it unsigned
    li t3, 1
    bne t2, t3, fail

    li a0, 9
    li t0, 0
    seqz t2, t0
    li t3, 1
    bne t2, t3, fail

    li a0, 10
    li t0, 77
    snez t2, t0
    li t3, 1
    bne t2, t3, fail

    # equal operands: strictly-less must be 0 (signed AND unsigned paths)
    li a0, 11
    li t0, 7
    li t1, 7
    sltu t2, t0, t1
    bnez t2, fail

    li a0, 12
    sltiu t2, t0, 7
    bnez t2, fail

    li a0, 13
    li t0, 1
    seqz t2, t0             # sltiu 1 < 1: false
    bnez t2, fail

    li a0, 14
    snez t2, zero           # sltu 0 < 0: false
    bnez t2, fail

    li a0, 15
    li t0, 0x80000000
    li t1, 0x80000000
    sltu t2, t0, t1
    bnez t2, fail

    li a0, 0
fail:
    ecall
