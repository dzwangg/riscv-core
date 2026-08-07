# How it works

A walkthrough of what actually happens inside `rtl/cpu.v`, written to be read
next to the code.

## The big picture

The CPU is a loop in hardware. Every clock cycle it does one full instruction:

1. **Fetch** — read the 32-bit instruction at address `pc`
2. **Decode** — split those 32 bits into fields: which operation, which registers, which constant
3. **Execute** — do the arithmetic / comparison / address math
4. **Commit** — write one register, maybe touch memory, pick the next `pc`

Single-cycle means all four happen between two clock edges. Nothing overlaps,
so there are no pipeline hazards to manage — the design trades speed for
being easy to reason about (and to prove correct).

## Life of one instruction: `addi t0, t0, 1`

The assembler encodes this as the word `0x00128293`. Here's its cycle:

**Fetch.** `imem_addr = pc` goes out; the testbench's RAM returns the word,
which becomes `instr`.

**Decode.** Fixed bit-fields are sliced out (see the `---- decode ----`
section): `opcode = 0010011` (OP_IMM), `rs1 = 5` (t0), `rd = 5` (t0),
`funct3 = 000` (add), and the I-type immediate `imm_i = 1`. RISC-V puts these
fields in the same place in every instruction of a given format, which is why
decode is just wire slicing — no state machine, no microcode.

**Execute.** The ALU (`---- ALU ----`) sees `funct3 = 000` and computes
`rv1 + alu_b`, where `alu_b` is the immediate because this is an OP_IMM
instruction. Result: t0's value plus 1.

**Commit.** The writeback block (`---- next PC and writeback ----`) selects
`alu_out` as `wb_data`, and on the clock edge `regs[5]` is written and
`pc <= pc + 4`. Done — one instruction, one cycle.

## A load: `lw t1, 8(sp)`

Same fetch/decode, but execute is *address* math: `mem_addr = rv1 + imm_i`
(sp + 8). The address goes out on `dmem_addr`, RAM answers combinationally,
and the load unit extracts the right bytes: for `lb`/`lh` the addressed byte
or halfword is shifted down and **sign-extended** (a 0xFF byte becomes -1,
not 255); `lbu`/`lhu` zero-extend instead. Getting this extension right is
one of the classic CPU bugs — `tests/mem_byte.s` exists mostly to catch it.

Stores mirror this: the data is replicated across the 32-bit word and 4
byte-enable wires (`dmem_we`) tell RAM which byte lanes to actually write, so
an `sb` can change one byte without disturbing its neighbors.

## A branch: `blt t0, t1, loop`

The branch comparator (`---- branch condition ----`) is separate from the
ALU. For `blt` it does a **signed** compare of `rv1 < rv2`; if true,
`next_pc = pc + imm_b` (the branch offset), otherwise `pc + 4`. The
signed/unsigned distinction matters: 0xFFFFFFFF is -1 to `blt` but the
biggest possible number to `bltu`. `tests/branch.s` checks all six branch
types in both taken and not-taken directions, including equal operands.

## Starting and stopping

Reset forces `pc = 0`, so programs are simply loaded at address 0. There is
no operating system: when a program executes `ecall`, the core raises
`halted` and freezes; whatever is in register `a0` at that moment is the
exit code (0 = success). The register `x0` is special-cased everywhere to
read as zero and swallow writes — that's the RISC-V spec, and `tests/x0.s`
proves it.

## The testbench: a tiny fake computer

`tb/tb.v` surrounds the core with just enough world to run programs: 64 KiB
of RAM (a Verilog array loaded from the program's hex file), a clock, and one
peripheral — a console at address `0x1000_0000` where any stored byte is
printed. The pass/fail verdict ("EXIT n") is printed to **stderr** so a
program's own console output on stdout can never be confused with, or forge,
the harness verdict.

## The assembler: two passes

`tools/asm.py` translates assembly text to the hex image. Pass 1 walks the
program only to learn each label's address (a forward branch's target isn't
known until later lines are seen). Pass 2 encodes each instruction into its
32-bit word using those addresses. Pseudo-instructions (`li`, `j`, `mv`,
`ret`…) expand into real RV32I instructions first — `li t0, 0xdeadbeef`
becomes a `lui` + `addi` pair, with a sign-adjustment on the upper half
because `addi`'s constant is signed.

## Questions this project should let you answer

- **Why single-cycle?** Correctness first: it's the simplest design that runs
  real programs, and every behavior is directly testable. A pipeline is a
  performance upgrade on top of proven semantics.
- **What was the hardest bug?** Verilog's ternary silently turned the
  arithmetic right shift into a logical one (an unsigned branch of `?:`
  strips signedness), so `sra` of a negative number zero-filled. A test
  caught it; the fix isolates the signed shift on its own wire.
- **How do you know the tests are good?** Mutation testing: deliberately
  seeded bugs (SLTU as `<=`, a 16-register file, JALR not clearing bit 0,
  branches writing a register) and confirmed the suite fails each one.
- **What would you build next?** A 5-stage pipeline: throughput of one
  instruction per cycle at a much faster clock, at the cost of forwarding
  paths and hazard logic — then run the official riscv-tests under the real
  GCC toolchain.
