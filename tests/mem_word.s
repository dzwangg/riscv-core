# sw / lw — offsets, negative offsets, overwrite

    li sp, 0x8000           # scratch area well above code

    li a0, 1
    li t0, 0xcafebabe
    sw t0, 0(sp)
    lw t1, 0(sp)
    bne t1, t0, fail

    li a0, 2
    li t0, 0x11111111
    li t1, 0x22222222
    sw t0, 4(sp)
    sw t1, 8(sp)
    lw t2, 4(sp)
    lw t3, 8(sp)
    bne t2, t0, fail
    li a0, 3
    bne t3, t1, fail

    li a0, 4
    addi t4, sp, 16
    li t0, 0x33333333
    sw t0, -4(t4)           # negative offset -> sp+12
    lw t1, 12(sp)
    bne t1, t0, fail

    li a0, 5
    li t0, 0x44444444
    li t1, 0x55555555
    sw t0, 20(sp)
    sw t1, 20(sp)           # overwrite
    lw t2, 20(sp)
    bne t2, t1, fail

    li a0, 0
fail:
    ecall
