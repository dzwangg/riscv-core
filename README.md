# riscv-core

![tests](https://github.com/dzwangg/riscv-core/actions/workflows/tests.yml/badge.svg)

A single-cycle RISC-V (RV32I) CPU written from scratch in Verilog, with its own
two-pass assembler and a self-checking test suite. Everything runs in simulation —
no hardware required.

```
$ make sierpinski
****************************************************************
**  **  **  **  **  **  **  **  **  **  **  **  **  **  **  **
****    ****    ****    ****    ****    ****    ****    ****
**      **      **      **      **      **      **      **
********        ********        ********        ********
...
```

That triangle is drawn by RISC-V assembly executing on the CPU in `rtl/cpu.v`,
printing one byte at a time through a memory-mapped console port.

## What's here

| Piece | File | What it does |
|---|---|---|
| CPU core | `rtl/cpu.v` | Single-cycle RV32I: all base integer instructions, decoded and executed in one cycle each |
| Testbench | `tb/tb.v` | 64 KiB RAM, console MMIO, cycle limit, optional VCD waveform dump |
| Assembler | `tools/asm.py` | Two-pass RV32I assembler (labels, pseudo-instructions, `.word`/`.asciz` data) |
| Tests | `tests/*.s` | 15 self-checking programs, ~160 individual assertions |
| Demos | `programs/*.s` | `hello.s`, `sierpinski.s` |

## Quick start

```sh
brew install icarus-verilog   # or: apt install iverilog
make test                     # assemble + run the whole suite
make hello                    # run a demo program
python3 run_tests.py programs/hello.s --vcd wave.vcd   # dump a waveform
```

## How it works

*(Deeper walkthrough — life of an instruction, design decisions:
[docs/how-it-works.md](docs/how-it-works.md))*

Every clock cycle the CPU fetches the instruction at `pc`, decodes it, executes
it, and commits the result — program counter, one optional register write, one
optional memory access — before the next edge. No pipeline, no stalls, no
hazards: the simplest design that runs real programs.

```
        +--------------------------------------------------+
        |                     cpu.v                         |
  pc -> | fetch -> decode -> ALU / branch / addr -> commit  |
        |            |                                      |
        |         regfile (x0..x31, x0 hardwired to 0)      |
        +----+---------------------------+-----------------+
             | imem (read)               | dmem (read/write, byte enables)
        +----+---------------------------+-----------------+
        |            64 KiB unified RAM (tb.v)              |
        |   0x1000_0000: console — stores print to stdout   |
        +---------------------------------------------------+
```

Program contract: execution starts at address 0; `ecall` ends the program with
the exit code in `a0` (0 = success). The testbench prints the exit code and any
console output.

## Testing

Each test in `tests/` is a self-checking assembly program: before every
assertion it loads a case number into `a0`, so a failure exits with the number
of the exact case that broke. `run_tests.py` assembles each test with
`tools/asm.py`, runs it on the simulated CPU, and checks for exit code 0.

The suite covers each instruction group, with deliberate attention to the
classic trip-ups: arithmetic vs logical shift of negative values, signed vs
unsigned comparison at 0x80000000, equal-operand edges of every comparison,
sign extension of `lb`/`lh`, byte-lane isolation of `sb`/`sh`, link-register
values and bit-0 clearing of `jal`/`jalr`, register-file aliasing, and writes
to `x0` being discarded.

Coverage was validated by mutation testing: seeded bugs (SLTU as `<=`, a
16-entry register file, JALR without bit-0 clearing, branches writing a
destination register) all fail the suite.

## Limitations (by design)

- RV32I base ISA only — no M/C extensions, CSRs, or interrupts; `fence` is a
  no-op and `ecall` halts (there's no OS to call).
- Naturally aligned loads/stores only.
- Single-cycle with combinational memory read — correct, not fast. The point
  of this milestone is a working, fully tested core.

## Roadmap

- [ ] 5-stage pipeline (IF/ID/EX/MEM/WB) with forwarding and hazard detection
- [ ] Run the official `riscv-tests` suite via the RISC-V GCC toolchain
- [ ] Synthesize with Yosys + nextpnr for an iCE40 FPGA; UART console
