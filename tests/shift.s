# sll / srl / sra and immediate forms — shamt edges 0 and 31, sign behavior

    li a0, 1
    li t0, 1
    slli t1, t0, 31
    li t2, 0x80000000
    bne t1, t2, fail

    li a0, 2
    li t0, 0xdeadbeef
    slli t1, t0, 0          # shift by 0 is identity
    bne t1, t0, fail

    li a0, 3
    li t0, 0x80000000
    srli t1, t0, 31         # logical: zero-fill
    li t2, 1
    bne t1, t2, fail

    li a0, 4
    li t0, 0x80000000
    srai t1, t0, 31         # arithmetic: sign-fill -> all ones
    li t2, -1
    bne t1, t2, fail

    li a0, 5
    li t0, 0x40000000
    srai t1, t0, 4          # positive value: sra == srl
    li t2, 0x04000000
    bne t1, t2, fail

    li a0, 6
    li t0, -16
    srai t1, t0, 2          # -16 >> 2 = -4
    li t2, -4
    bne t1, t2, fail

    li a0, 7
    li t0, 0xdeadbeef
    li t1, 4
    sll t2, t0, t1
    li t3, 0xeadbeef0
    bne t2, t3, fail

    li a0, 8
    srl t2, t0, t1
    li t3, 0x0deadbee
    bne t2, t3, fail

    li a0, 9
    sra t2, t0, t1          # 0xdeadbeef is negative -> sign-fill with f
    li t3, 0xfdeadbee
    bne t2, t3, fail

    li a0, 10
    li t1, 37               # register shift uses only low 5 bits: 37 % 32 = 5
    li t0, 32
    srl t2, t0, t1
    li t3, 1
    bne t2, t3, fail

    li a0, 0
fail:
    ecall
