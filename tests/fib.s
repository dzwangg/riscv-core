# integration: iterative fibonacci with a stack-based function call
# fib(10) = 55, computed in a callee that saves/restores registers

    li sp, 0x10000          # stack at top of RAM

    li a0, 1
    li a1, 10
    jal ra, fib
    li t0, 55
    bne a2, t0, fail

    li a0, 2
    li a1, 1
    jal ra, fib
    li t0, 1
    bne a2, t0, fail

    li a0, 3
    li a1, 0
    jal ra, fib
    bnez a2, fail

    li a0, 0
    ecall

# fib(a1) -> a2, clobbers nothing else (saves temps on the stack)
fib:
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    li s0, 0                # fib(0)
    li s1, 1                # fib(1)
    mv s2, a1
    beqz s2, fib_zero
loop:
    addi s2, s2, -1
    beqz s2, fib_done
    add t0, s0, s1
    mv s0, s1
    mv s1, t0
    j loop
fib_zero:
    li s1, 0
fib_done:
    mv a2, s1
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

fail:
    ecall
