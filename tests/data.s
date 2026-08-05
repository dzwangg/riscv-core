# la / .word / .asciz — data access, string scan

    li a0, 1
    la t0, words
    lw t1, 0(t0)
    li t2, 0x00c0ffee
    bne t1, t2, fail

    li a0, 2
    lw t1, 4(t0)
    li t2, 0xdeadbeef
    bne t1, t2, fail

    li a0, 3
    lw t1, 8(t0)
    li t2, -1
    bne t1, t2, fail

    # strlen("riscv") == 5 by scanning to the NUL
    li a0, 4
    la t0, str
    li t1, 0
strlen:
    lb t2, 0(t0)
    beqz t2, strdone
    addi t0, t0, 1
    addi t1, t1, 1
    j strlen
strdone:
    li t2, 5
    bne t1, t2, fail

    # first character is 'r'
    li a0, 5
    la t0, str
    lbu t1, 0(t0)
    li t2, 'r'
    bne t1, t2, fail

    li a0, 0
    ecall

fail:
    ecall

words:
    .word 0x00c0ffee, 0xdeadbeef, -1
str:
    .asciz "riscv"
