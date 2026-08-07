#!/usr/bin/env python3
"""Build and run the official riscv-tests ISA suite (rv32ui) on the core.

Requires a RISC-V cross-compiler. Set RISCV_PREFIX if yours isn't
riscv64-elf- (e.g. RISCV_PREFIX=riscv64-unknown-elf- on Ubuntu).
"""

import os
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).parent
REPO = HERE.parent
BUILD = REPO / "build" / "compliance"
SIM = REPO / "build" / "sim.vvp"

PREFIX = os.environ.get("RISCV_PREFIX", "riscv64-elf-")

SKIP = {
    "ma_data": "misaligned accesses unsupported (by design)",
}


def run(cmd):
    p = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit(f"$ {' '.join(str(c) for c in cmd)}\n{p.stdout}{p.stderr}")
    return p


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    run(["iverilog", "-g2012", "-Wall", "-o", SIM,
         REPO / "rtl" / "cpu.v", REPO / "tb" / "tb.v"])

    tests = sorted((HERE / "vendor" / "rv32ui").glob("*.S"))
    failed = skipped = 0
    for src in tests:
        name = src.stem
        if name in SKIP:
            skipped += 1
            print(f"SKIP  {name}  ({SKIP[name]})")
            continue

        march = "rv32i_zifencei" if name == "fence_i" else "rv32i"
        elf = BUILD / f"{name}.elf"
        run([PREFIX + "gcc", f"-march={march}", "-mabi=ilp32",
             "-nostdlib", "-nostartfiles", "-ffreestanding",
             "-I", HERE / "env", "-I", HERE / "vendor",
             "-T", HERE / "env" / "link.ld", src, "-o", elf])
        binf = BUILD / f"{name}.bin"
        run([PREFIX + "objcopy", "-O", "binary", elf, binf])

        data = binf.read_bytes()
        data += b"\0" * (-len(data) % 4)
        hexf = BUILD / f"{name}.hex"
        hexf.write_text("".join(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n"
                                for i in range(0, len(data), 4)))

        p = subprocess.run(["vvp", "-n", str(SIM), f"+hex={hexf}"],
                           capture_output=True, text=True)
        m = re.search(r"^EXIT (\d+)\s*$", p.stderr, re.M)
        code = int(m.group(1)) if m else None
        if code == 0:
            print(f"PASS  {name}")
        else:
            failed += 1
            what = "no exit/timeout" if code is None else f"failed case {code}"
            print(f"FAIL  {name}  ({what})")

    print(f"\n{len(tests) - failed - skipped}/{len(tests) - skipped} official "
          f"rv32ui tests passed ({skipped} skipped)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
