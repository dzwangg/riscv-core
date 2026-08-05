# all six branches, taken and not-taken, signed/unsigned edges

    li a0, 1
    li t0, 5
    li t1, 5
    beq t0, t1, ok1         # equal: must take
    j fail
ok1:

    li a0, 2
    li t1, 6
    beq t0, t1, fail        # not equal: must not take

    li a0, 3
    bne t0, t1, ok3
    j fail
ok3:

    li a0, 4
    bne t0, t0, fail

    li a0, 5
    li t0, -1
    li t1, 1
    blt t0, t1, ok5         # signed -1 < 1
    j fail
ok5:

    li a0, 6
    blt t1, t0, fail        # 1 < -1 is false signed

    li a0, 7
    bltu t1, t0, ok7        # unsigned 1 < 0xffffffff
    j fail
ok7:

    li a0, 8
    bltu t0, t1, fail       # 0xffffffff < 1 is false unsigned

    li a0, 9
    bge t1, t0, ok9         # 1 >= -1 signed
    j fail
ok9:

    li a0, 10
    bge t0, t1, fail

    li a0, 11
    li t0, 7
    bge t0, t0, ok11        # x >= x
    j fail
ok11:

    li a0, 12
    li t0, 0x80000000
    li t1, 0x7fffffff
    bgeu t0, t1, ok12       # unsigned 0x80000000 >= 0x7fffffff
    j fail
ok12:

    li a0, 13
    bge t1, t0, ok13        # signed 0x7fffffff >= 0x80000000
    j fail
ok13:

    # equal operands: >= takes, strictly-less does not
    li a0, 15
    li t0, 9
    li t1, 9
    bgeu t0, t1, ok15
    j fail
ok15:

    li a0, 16
    li t0, 3
    li t1, 7
    bgeu t0, t1, fail       # 3 >= 7 unsigned is false: must not take

    li a0, 17
    li t0, 5
    blt t0, t0, fail        # x < x signed: must not take

    li a0, 18
    bltu t0, t0, fail       # x < x unsigned: must not take

    li a0, 19
    bge t0, t0, ok19        # x >= x signed: must take
    j fail
ok19:

    # backward branch: loop down from 3
    li a0, 14
    li t0, 3
    li t1, 0
back:
    addi t1, t1, 1
    addi t0, t0, -1
    bnez t0, back
    li t2, 3
    bne t1, t2, fail

    li a0, 0
fail:
    ecall
