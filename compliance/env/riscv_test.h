// Minimal test environment for the official riscv-tests ISA suite.
//
// The upstream tests are portable: they expect the target to supply this
// header. Ours maps the test lifecycle onto this core's conventions —
// execution starts at _start (address 0), and ECALL halts with the exit
// code in a0 (0 = pass, nonzero = number of the failing test case).
// No CSRs, no trap handlers: the rv32ui tests need neither.

#ifndef _ENV_RISCV_TEST_H
#define _ENV_RISCV_TEST_H

#define RVTEST_RV32U
#define TESTNUM gp

#define RVTEST_CODE_BEGIN \
    .section .text.init;  \
    .globl _start;        \
_start:

#define RVTEST_CODE_END

#define RVTEST_PASS \
    li a0, 0;       \
    ecall

// TESTNUM holds the current test case number; report it as the exit code.
// If it is somehow zero, exit 127 so a failure can never look like a pass.
#define RVTEST_FAIL   \
    mv a0, TESTNUM;   \
    bnez a0, 1f;      \
    li a0, 127;       \
1:  ecall

#define RVTEST_DATA_BEGIN .data; .balign 4;
#define RVTEST_DATA_END

#endif
