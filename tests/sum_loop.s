# integration: sum 1..100 = 5050 with a backward-branch loop

    li a0, 1
    li t0, 0                # sum
    li t1, 1                # i
    li t2, 100
loop:
    add t0, t0, t1
    addi t1, t1, 1
    bge t2, t1, loopcheck
    j done
loopcheck:
    j loop
done:
    li t3, 5050
    bne t0, t3, fail

    li a0, 0
fail:
    ecall
