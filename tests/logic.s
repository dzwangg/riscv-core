# and / or / xor and their immediate forms

    li a0, 1
    li t0, 0xff00ff00
    li t1, 0x0ff00ff0
    and t2, t0, t1
    li t3, 0x0f000f00
    bne t2, t3, fail

    li a0, 2
    or t2, t0, t1
    li t3, 0xfff0fff0
    bne t2, t3, fail

    li a0, 3
    xor t2, t0, t1
    li t3, 0xf0f0f0f0
    bne t2, t3, fail

    li a0, 4
    li t0, 0x5a5
    andi t1, t0, 0xf0       # 0xa0
    li t2, 0xa0
    bne t1, t2, fail

    li a0, 5
    li t0, 0x500
    ori t1, t0, 0xaa        # 0x5aa
    li t2, 0x5aa
    bne t1, t2, fail

    li a0, 6
    li t0, 0xff
    xori t1, t0, -1         # ~0xff = 0xffffff00
    li t2, 0xffffff00
    bne t1, t2, fail

    li a0, 7
    li t0, 0x12345678
    andi t1, t0, -1         # imm sign-extends to all ones
    bne t1, t0, fail

    li a0, 8
    li t0, 0xdeadbeef
    not t1, t0
    li t2, 0x21524110
    bne t1, t2, fail

    li a0, 0
fail:
    ecall
