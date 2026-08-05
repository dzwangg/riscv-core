# prints a string through the console MMIO port, one byte at a time

    la t0, msg
    li t1, 0x10000000       # console port
loop:
    lb t2, 0(t0)
    beqz t2, done
    sb t2, 0(t1)
    addi t0, t0, 1
    j loop
done:
    li a0, 0
    ecall

msg:
    .asciz "hello from my cpu!\n"
