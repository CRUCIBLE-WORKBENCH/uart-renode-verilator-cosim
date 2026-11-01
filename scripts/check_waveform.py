#!/usr/bin/env python3
"""Check that the recorded VCD contains real UART bus/serial/IRQ activity."""
import argparse
from pathlib import Path


def check(path):
    signals = {}
    values = {}
    declarations = 0
    timestamps = 0
    enddefinitions = False
    with path.open() as stream:
        for raw in stream:
            line = raw.strip()
            if line.startswith("$var "):
                parts = line.split()
                signals.setdefault(parts[3], set()).add(parts[4])
                declarations += 1
            elif line.startswith("$enddefinitions"):
                enddefinitions = True
            elif line.startswith("#"):
                timestamps += 1
            elif enddefinitions and line.startswith("b"):
                bits, code = line[1:].split()
                if set(bits) <= {"0", "1"}:
                    values.setdefault(code, set()).add(int(bits, 2))
            elif enddefinitions and line and line[0] in "01":
                values.setdefault(line[1:], set()).add(int(line[0]))

    def observed(name):
        return set().union(*(values.get(code, set()) for code, names in signals.items() if name in names))

    problems = []
    if not enddefinitions or timestamps < 2:
        problems.append("missing VCD definitions or timed samples")
    if not {0x00010041, 0x0001005A} <= observed("io_apb_PRDATA"):
        problems.append("UART read-data trace does not contain received A and Z")
    for name in ("clk", "uart_line", "uart_irq"):
        if not {0, 1} <= observed(name):
            problems.append("no low/high activity on " + name)
    return problems, {"bytes": path.stat().st_size, "signal_declarations": declarations,
                      "unique_signal_codes": len(signals), "timestamps": timestamps}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    args = parser.parse_args()
    try:
        problems, stats = check(args.vcd)
    except (OSError, ValueError) as error:
        print("FAIL waveform:", error)
        return 1
    if problems:
        print("FAIL waveform: " + "; ".join(problems))
        return 1
    print("PASS waveform: UART A/Z readbacks, clock, serial line and IRQ activity")
    print("signals: %(signal_declarations)d declarations, %(unique_signal_codes)d unique codes" % stats)
    print("samples: %(timestamps)d timestamps; size: %(bytes)d bytes" % stats)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
