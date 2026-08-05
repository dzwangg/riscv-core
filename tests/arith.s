# add / addi / sub — including negatives and wraparound

    li a0, 1
    li t0, 5
    addi t1, t0, 7          # 12
    li t2, 12
    bne t1, t2, fail

    li a0, 2
    addi t1, t0, -9         # -4
    li t2, -4
    bne t1, t2, fail

    li a0, 3
    li t0, 100
    li t1, -30
    add t2, t0, t1          # 70
    li t3, 70
    bne t2, t3, fail

    li a0, 4
    li t0, 0x7fffffff
    addi t1, t0, 1          # signed overflow wraps to 0x80000000
    li t2, 0x80000000
    bne t1, t2, fail

    li a0, 5
    li t0, 7
    li t1, 10
    sub t2, t0, t1          # -3
    li t3, -3
    bne t2, t3, fail

    li a0, 6
    li t0, 0x80000000
    li t1, 1
    sub t2, t0, t1          # 0x7fffffff
    li t3, 0x7fffffff
    bne t2, t3, fail

    li a0, 7
    li t0, 42
    sub t1, t0, t0          # 0
    bnez t1, fail

    li a0, 0
fail:
    ecall
