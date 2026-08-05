# lui / auipc

    li a0, 1
    lui t0, 0xdeadb
    li t1, 0xdeadb000
    bne t0, t1, fail

    li a0, 2
    lui t0, 0xfffff
    li t1, 0xfffff000
    bne t0, t1, fail

    li a0, 3
    lui t0, 0
    bnez t0, fail

    li a0, 4
    auipc t0, 0             # t0 = address of this auipc
    auipc t1, 0             # t1 = t0 + 4 (next instruction)
    sub t2, t1, t0
    li t3, 4
    bne t2, t3, fail

    li a0, 5
    auipc t0, 1             # pc + 0x1000
    auipc t1, 0             # pc' = pc + 4
    sub t2, t0, t1          # 0x1000 - 4
    li t3, 0xffc
    bne t2, t3, fail

    li a0, 0
fail:
    ecall
