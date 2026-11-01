#!/usr/bin/env python3
"""Judge a Renode log from scripts/uart_cosim.resc.

Renode exits 0 even when the co-simulated model fails to load, so the exit
status proves nothing. A run passes only if every labelled register read and
interrupt-line state is what the RTL must produce, the script reached its end
marker, and Renode logged no error.

    check_uart_log.py LOG [--expect "LABEL=0xVALUE" ...]

--expect overrides one expected value (a number, or True/False for an IRQ
state); smoke.sh uses it to prove that a wrong expectation is rejected.
"""
import argparse
import re
import sys
from pathlib import Path

DONE_MARKER = "UART_COSIM_DONE"

# Register reads are numbers; `irq State` (the RTL's interrupt pin, seen
# through Renode GPIO input 0) is True or False.
EXPECTED = [
    ("STATUS reset", 0x00200000),
    ("IRQ reset", False),
    ("STATUS tx+rx irq enabled", 0x00200103),
    ("IRQ tx empty", True),
    ("STATUS rx irq enabled", 0x00200002),
    ("IRQ nothing received", False),
    ("STATUS irqs disabled", 0x00200000),
    ("DATA rx empty", 0x00000000),
    ("DATA 'A' still on the wire", 0x00000000),
    ("DATA rx 'A'", 0x00010041),
    ("STATUS 'Z' waiting", 0x01200202),
    ("IRQ rx pending", True),
    ("DATA rx 'Z'", 0x0001005A),
    ("IRQ rx drained", False),
]

# "%Error" is the Verilated model's own output (an assertion or $error),
# which Renode copies into its log.
ERROR_PATTERNS = ("[ERROR]", "There was an error", "Operation timeout", "%Error")

LABELS = {label for label, _ in EXPECTED}
VALUE_LINE = re.compile(r"^(?:0x([0-9A-Fa-f]{8})|(True|False))$")


def readbacks(log):
    """Return (label, value) for each read that follows an echo label."""
    pairs = []
    label = None
    for raw in log.splitlines():
        line = raw.strip()
        if line in LABELS:
            label = line
            continue
        m = VALUE_LINE.match(line)
        if m and label is not None:
            value = int(m.group(1), 16) if m.group(1) else m.group(2) == "True"
            pairs.append((label, value))
            label = None
    return pairs


def show(value):
    return str(value) if isinstance(value, bool) else "0x%08X" % value


def problems(log, expected=EXPECTED):
    """Every reason the log is not a passing run; empty means it passed."""
    found = []
    for pattern in ERROR_PATTERNS:
        for line in log.splitlines():
            if pattern in line:
                found.append("Renode reported: " + line.strip())
    got = readbacks(log)
    for i, (label, want) in enumerate(expected):
        if i >= len(got):
            found.append("missing read: %s (want %s)" % (label, show(want)))
            continue
        got_label, value = got[i]
        if got_label != label or type(value) is not type(want) or value != want:
            found.append("%s: got %s=%s, want %s" % (label, got_label, show(value), show(want)))
    if len(got) > len(expected):
        found.append("unexpected extra reads: %d" % (len(got) - len(expected)))
    if not any(line.strip() == DONE_MARKER for line in log.splitlines()):
        found.append("script did not reach " + DONE_MARKER)
    return found


def with_overrides(overrides):
    expected = list(EXPECTED)
    for item in overrides:
        label, sep, value = item.rpartition("=")
        if not sep or label not in LABELS:
            raise SystemExit("bad --expect %r; labels: %s" % (item, ", ".join(sorted(LABELS))))
        parsed = value == "True" if value in ("True", "False") else int(value, 0)
        if type(parsed) is not type(dict(EXPECTED)[label]):
            raise SystemExit("bad --expect %r: %s takes %s" % (item, label, type(dict(EXPECTED)[label]).__name__))
        expected = [(l, parsed if l == label else v) for l, v in expected]
    return expected


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("log", type=Path)
    parser.add_argument("--expect", action="append", default=[], metavar="LABEL=VALUE")
    args = parser.parse_args(argv)
    found = problems(args.log.read_text(errors="replace"), with_overrides(args.expect))
    if found:
        print("FAIL %s" % args.log)
        for p in found:
            print("  " + p)
        return 1
    print("PASS %s: %d reads match the RTL" % (args.log, len(EXPECTED)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
