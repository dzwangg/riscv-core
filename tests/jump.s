# jal / jalr — link register values and control transfer

    li a0, 1
    jal ra, target1         # ra = pc + 4
    j check1                # jal must skip this only if it jumped
    j fail
target1:
    jalr zero, 0(ra)        # return: lands on "j check1"
check1:

    # link value: ra must equal address of the instruction after the jal
    li a0, 2
    auipc t0, 0             # t0 = here
    jal ra, target2
after2:
target2:
    sub t1, ra, t0          # ra - t0 = 8 (auipc, jal)
    li t2, 8
    bne t1, t2, fail

    # jal x0 (plain j) writes nothing
    li a0, 3
    li t3, 99
    j nowhere
nowhere:
    li t4, 99
    bne t3, t4, fail

    # call/return with jalr through a register
    li a0, 4
    la t0, func
    li s0, 0
    jalr ra, 0(t0)
    li t1, 123
    bne s0, t1, fail

    # jalr with a nonzero offset
    li a0, 5
    la t0, func
    addi t0, t0, -4         # point one instruction early
    li s0, 0
    jalr ra, 4(t0)          # offset lands back on func
    li t1, 123
    bne s0, t1, fail

    # jalr must clear bit 0 of the target (spec). Fetch ignores pc[1:0], so
    # observe the PC itself with auipc at the landing point.
    li a0, 6
    la t0, oddtgt
    addi t0, t0, 1          # deliberately odd target address
    jalr ra, 0(t0)
    j jalr_done
oddtgt:
    auipc t1, 0             # t1 = the actual PC we landed on
    la t2, oddtgt
    bne t1, t2, fail        # equal only if jalr cleared bit 0
    ret
jalr_done:

    li a0, 0
    ecall

func:
    li s0, 123
    ret

fail:
    ecall
