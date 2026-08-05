#!/usr/bin/env python3
"""Two-pass RV32I assembler.

Supports the full RV32I base ISA plus the pseudo-instructions and directives
used by the tests and demo programs. Output is a hex image (one 32-bit word
per line, little-endian byte order within the word) for $readmemh.

Usage: asm.py input.s output.hex
"""

import re
import sys

# ---------------------------------------------------------------------------
# registers

REGS = {f"x{i}": i for i in range(32)}
ABI = ("zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 "
       "s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6").split()
REGS.update({name: i for i, name in enumerate(ABI)})
REGS["fp"] = 8


class AsmError(Exception):
    pass


def reg(s):
    s = s.strip()
    if s not in REGS:
        raise AsmError(f"unknown register '{s}'")
    return REGS[s]


def imm(s, labels=None):
    s = s.strip()
    if labels is not None and s in labels:
        return labels[s]
    if len(s) >= 3 and s[0] == "'" and s[-1] == "'":
        ch = s[1:-1].encode().decode("unicode_escape")
        if len(ch) == 1:
            return ord(ch)
        raise AsmError(f"bad character literal {s}")
    try:
        return int(s, 0)
    except ValueError:
        raise AsmError(f"bad immediate '{s}'")


# ---------------------------------------------------------------------------
# encoders

def check_range(val, lo, hi, what):
    if not lo <= val <= hi:
        raise AsmError(f"{what} {val} out of range [{lo}, {hi}]")


def enc_r(f7, f3, rd, rs1, rs2):
    return f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | 0x33


def enc_i(f3, opcode, rd, rs1, val):
    check_range(val, -2048, 2047, "immediate")
    return (val & 0xFFF) << 20 | rs1 << 15 | f3 << 12 | rd << 7 | opcode


def enc_shift_i(f7, f3, rd, rs1, shamt):
    check_range(shamt, 0, 31, "shift amount")
    return f7 << 25 | shamt << 20 | rs1 << 15 | f3 << 12 | rd << 7 | 0x13


def enc_s(f3, rs2, rs1, val):
    check_range(val, -2048, 2047, "store offset")
    v = val & 0xFFF
    return (v >> 5) << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | (v & 0x1F) << 7 | 0x23


def enc_b(f3, rs1, rs2, off):
    check_range(off, -4096, 4094, "branch offset")
    if off & 1:
        raise AsmError("branch target not 2-byte aligned")
    u = off & 0x1FFF
    return ((u >> 12) << 31 | ((u >> 5) & 0x3F) << 25 | rs2 << 20 | rs1 << 15
            | f3 << 12 | ((u >> 1) & 0xF) << 8 | ((u >> 11) & 1) << 7 | 0x63)


def enc_u(opcode, rd, val):
    check_range(val, 0, 0xFFFFF, "upper immediate")
    return val << 12 | rd << 7 | opcode


def enc_j(rd, off):
    check_range(off, -(1 << 20), (1 << 20) - 2, "jump offset")
    if off & 1:
        raise AsmError("jump target not 2-byte aligned")
    u = off & 0x1FFFFF
    return ((u >> 20) << 31 | ((u >> 1) & 0x3FF) << 21 | ((u >> 11) & 1) << 20
            | ((u >> 12) & 0xFF) << 12 | rd << 7 | 0x6F)


R_OPS = {"add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
         "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
         "or": (0x00, 6), "and": (0x00, 7)}
I_OPS = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SHIFT_OPS = {"slli": (0x00, 1), "srli": (0x00, 5), "srai": (0x20, 5)}
LOAD_OPS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORE_OPS = {"sb": 0, "sh": 1, "sw": 2}
BRANCH_OPS = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}

MEM_RE = re.compile(r"^(-?\w+)\((\w+)\)$")


def split_hi_lo(val):
    """Split a 32-bit value for lui+addi (addi sign-extends, so round hi up)."""
    val &= 0xFFFFFFFF
    hi = ((val + 0x800) >> 12) & 0xFFFFF
    lo = val - ((hi << 12) & 0xFFFFFFFF) & 0xFFF
    if lo >= 0x800:
        lo -= 0x1000
    return hi, lo


def li_size(val):
    check_range(val, -(1 << 31), (1 << 32) - 1, "li value")
    return 4 if -2048 <= val <= 2047 else 8


# ---------------------------------------------------------------------------
# per-instruction size (pass 1) and encoding (pass 2)

def inst_size(mn, args):
    if mn == "li":
        return li_size(imm(args[1]))
    if mn == "la":
        return 8
    return 4


def encode(mn, args, addr, labels):
    """Return the list of 32-bit words for one (possibly pseudo) instruction."""
    if mn in R_OPS:
        f7, f3 = R_OPS[mn]
        return [enc_r(f7, f3, reg(args[0]), reg(args[1]), reg(args[2]))]
    if mn in I_OPS:
        return [enc_i(I_OPS[mn], 0x13, reg(args[0]), reg(args[1]), imm(args[2]))]
    if mn in SHIFT_OPS:
        f7, f3 = SHIFT_OPS[mn]
        return [enc_shift_i(f7, f3, reg(args[0]), reg(args[1]), imm(args[2]))]
    if mn in LOAD_OPS:
        m = MEM_RE.match(args[1].strip())
        if not m:
            raise AsmError(f"bad memory operand '{args[1]}'")
        return [enc_i(LOAD_OPS[mn], 0x03, reg(args[0]), reg(m.group(2)), imm(m.group(1)))]
    if mn in STORE_OPS:
        m = MEM_RE.match(args[1].strip())
        if not m:
            raise AsmError(f"bad memory operand '{args[1]}'")
        return [enc_s(STORE_OPS[mn], reg(args[0]), reg(m.group(2)), imm(m.group(1)))]
    if mn in BRANCH_OPS:
        target = imm(args[2], labels)
        return [enc_b(BRANCH_OPS[mn], reg(args[0]), reg(args[1]), target - addr)]
    if mn == "lui":
        return [enc_u(0x37, reg(args[0]), imm(args[1]))]
    if mn == "auipc":
        return [enc_u(0x17, reg(args[0]), imm(args[1]))]
    if mn == "jal":
        if len(args) == 1:          # jal label  -> rd = ra
            rd, target = 1, imm(args[0], labels)
        else:
            rd, target = reg(args[0]), imm(args[1], labels)
        return [enc_j(rd, target - addr)]
    if mn == "jalr":
        if len(args) == 1:          # jalr rs1   -> ra, 0(rs1)
            return [enc_i(0, 0x67, 1, reg(args[0]), 0)]
        m = MEM_RE.match(args[1].strip())
        if not m:
            raise AsmError(f"bad memory operand '{args[1]}'")
        return [enc_i(0, 0x67, reg(args[0]), reg(m.group(2)), imm(m.group(1)))]
    if mn == "ecall":
        return [0x00000073]
    if mn == "ebreak":
        return [0x00100073]
    if mn == "fence":
        return [0x0000000F]

    # ---- pseudo-instructions ----
    if mn == "nop":
        return [enc_i(0, 0x13, 0, 0, 0)]
    if mn == "mv":
        return [enc_i(0, 0x13, reg(args[0]), reg(args[1]), 0)]
    if mn == "not":
        return [enc_i(4, 0x13, reg(args[0]), reg(args[1]), -1)]
    if mn == "neg":
        return [enc_r(0x20, 0, reg(args[0]), 0, reg(args[1]))]
    if mn == "seqz":
        return [enc_i(3, 0x13, reg(args[0]), reg(args[1]), 1)]
    if mn == "snez":
        return [enc_r(0x00, 3, reg(args[0]), 0, reg(args[1]))]
    if mn == "li":
        rd, val = reg(args[0]), imm(args[1])
        if li_size(val) == 4:
            return [enc_i(0, 0x13, rd, 0, val)]
        hi, lo = split_hi_lo(val)
        return [enc_u(0x37, rd, hi), enc_i(0, 0x13, rd, rd, lo)]
    if mn == "la":
        rd, val = reg(args[0]), imm(args[1], labels)
        hi, lo = split_hi_lo(val)
        return [enc_u(0x37, rd, hi), enc_i(0, 0x13, rd, rd, lo)]
    if mn == "j":
        return [enc_j(0, imm(args[0], labels) - addr)]
    if mn == "ret":
        return [enc_i(0, 0x67, 0, 1, 0)]
    if mn == "beqz":
        return [enc_b(0, reg(args[0]), 0, imm(args[1], labels) - addr)]
    if mn == "bnez":
        return [enc_b(1, reg(args[0]), 0, imm(args[1], labels) - addr)]
    if mn == "bgtz":
        return [enc_b(4, 0, reg(args[0]), imm(args[1], labels) - addr)]
    if mn == "blez":
        return [enc_b(5, 0, reg(args[0]), imm(args[1], labels) - addr)]

    raise AsmError(f"unknown instruction '{mn}'")


# ---------------------------------------------------------------------------
# parsing

STRING_RE = re.compile(r'^\.asciz\s+"((?:[^"\\]|\\.)*)"\s*$')

def unescape(s):
    """Resolve escapes and return raw bytes (chars must fit in one byte)."""
    try:
        return s.encode().decode("unicode_escape").encode("latin-1")
    except UnicodeEncodeError:
        raise AsmError(f'string "{s}" has characters above 0xff')


def parse_lines(path):
    """Yield (lineno, label|None, mnemonic|directive|None, args) tuples."""
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.split("#")[0].split("//")[0].strip()
            while line:
                m = re.match(r"^([A-Za-z_]\w*):\s*(.*)$", line)
                if m:
                    yield lineno, m.group(1), None, None
                    line = m.group(2)
                    continue
                if line.startswith(".asciz"):
                    sm = STRING_RE.match(line)
                    if not sm:
                        raise AsmError(f"line {lineno}: bad .asciz")
                    yield lineno, None, ".asciz", [unescape(sm.group(1))]
                else:
                    parts = line.split(None, 1)
                    mn = parts[0].lower()
                    args = [a.strip() for a in parts[1].split(",")] if len(parts) > 1 else []
                    yield lineno, None, mn, args
                line = ""


def assemble(path):
    items = list(parse_lines(path))

    # pass 1: label addresses
    labels = {}
    addr = 0
    for lineno, label, mn, args in items:
        try:
            if label is not None:
                if label in labels:
                    raise AsmError(f"duplicate label '{label}'")
                labels[label] = addr
            elif mn == ".asciz":
                addr += (len(args[0]) + 1 + 3) & ~3   # NUL-terminated, word-padded
            elif mn == ".word":
                addr = (addr + 3) & ~3
                addr += 4 * len(args)
            elif mn == ".align":
                a = 1 << imm(args[0])
                addr = (addr + a - 1) & ~(a - 1)
            elif mn is not None:
                addr = (addr + 3) & ~3          # instructions are word-aligned
                addr += inst_size(mn, args)
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}")

    # pass 2: emit bytes
    out = bytearray()
    for lineno, label, mn, args in items:
        try:
            if label is not None:
                continue
            if mn == ".asciz":
                out += args[0] + b"\0"
                while len(out) % 4:
                    out.append(0)
            elif mn == ".word":
                while len(out) % 4:
                    out.append(0)
                for a in args:
                    val = imm(a, labels)
                    check_range(val, -(1 << 31), (1 << 32) - 1, ".word value")
                    out += (val & 0xFFFFFFFF).to_bytes(4, "little")
            elif mn == ".align":
                a = 1 << imm(args[0])
                while len(out) % a:
                    out.append(0)
            else:
                while len(out) % 4:
                    out.append(0)
                for word in encode(mn, args, len(out), labels):
                    out += word.to_bytes(4, "little")
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}")

    while len(out) % 4:
        out.append(0)
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: asm.py input.s output.hex")
    try:
        data = assemble(sys.argv[1])
    except AsmError as e:
        sys.exit(f"{sys.argv[1]}: {e}")
    with open(sys.argv[2], "w") as f:
        for i in range(0, len(data), 4):
            f.write(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n")


if __name__ == "__main__":
    main()
