# draws a Sierpinski triangle: cell (x, y) is filled iff (x & y) == 0

    li t3, 0x10000000       # console port
    li s2, 32               # size
    li s0, 0                # y
yloop:
    li s1, 0                # x
xloop:
    and t0, s0, s1
    li t1, '*'
    beqz t0, put
    li t1, ' '
put:
    sb t1, 0(t3)
    sb t1, 0(t3)            # print twice: terminal cells are ~2x taller than wide
    addi s1, s1, 1
    blt s1, s2, xloop
    li t1, '\n'
    sb t1, 0(t3)
    addi s0, s0, 1
    blt s0, s2, yloop

    li a0, 0
    ecall
