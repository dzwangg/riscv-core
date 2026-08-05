#!/usr/bin/env python3
"""Build the simulator, assemble and run the test suite (or a single program).

Usage:
  python3 run_tests.py                   # run all tests in tests/
  python3 run_tests.py programs/hello.s  # assemble + run one program
  python3 run_tests.py --vcd t.vcd tests/arith.s
"""

import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).parent
BUILD = ROOT / "build"
SIM = BUILD / "sim.vvp"


def run(cmd, **kw):
    p = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if p.returncode != 0:
        sys.exit(f"$ {' '.join(str(c) for c in cmd)}\n{p.stdout}{p.stderr}")
    return p.stdout


def build_sim():
    BUILD.mkdir(exist_ok=True)
    run(["iverilog", "-g2012", "-Wall", "-o", SIM,
         ROOT / "rtl" / "cpu.v", ROOT / "tb" / "tb.v"])


def assemble(src):
    hexfile = BUILD / (pathlib.Path(src).stem + ".hex")
    run([sys.executable, ROOT / "tools" / "asm.py", src, hexfile])
    return hexfile


def simulate(hexfile, vcd=None):
    cmd = ["vvp", "-n", SIM, f"+hex={hexfile}"]
    if vcd:
        cmd.append(f"+vcd={vcd}")
    p = subprocess.run(cmd, capture_output=True, text=True)
    # the verdict lives on stderr, where the program's console can't reach
    m = re.search(r"^EXIT (\d+)\s*$", p.stderr, re.M)
    exit_code = int(m.group(1)) if m else None
    # hide iverilog chatter: image-smaller-than-memory warning, $finish notice
    console = re.sub(r"^WARNING: .*readmemh.*\n", "", p.stdout, flags=re.M)
    console = re.sub(r"^.*\$finish called at.*\n", "", console, flags=re.M)
    return exit_code, console


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("program", nargs="?", help="run one .s file instead of the suite")
    ap.add_argument("--vcd", help="write a VCD waveform (single-program mode)")
    args = ap.parse_args()

    build_sim()

    if args.program:
        code, console = simulate(assemble(args.program), vcd=args.vcd)
        print(console, end="")
        if code is None:
            sys.exit("no EXIT (timeout or crash)")
        if code != 0:
            print(f"program exited with code {code}", file=sys.stderr)
        sys.exit(1 if code else 0)   # don't sys.exit(code): 256 would wrap to 0

    tests = sorted((ROOT / "tests").glob("*.s"))
    failed = 0
    for t in tests:
        code, console = simulate(assemble(t))
        if code == 0:
            print(f"PASS  {t.name}")
        else:
            failed += 1
            what = "TIMEOUT/no exit" if code is None else f"exit {code}"
            print(f"FAIL  {t.name}  ({what})")
            if console.strip():
                print(f"      {console.strip()}")
    print(f"\n{len(tests) - failed}/{len(tests)} tests passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
