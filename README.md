# UART co-simulation: Renode + Verilator under Crucible

Renode emulates the system and Verilator runs one real piece of RTL beside it.
The RTL here is a SpinalHDL APB3 UART controller. Renode drives its bus
registers and feeds bytes into its receive pin. Every value the demo checks
comes back out of the Verilated RTL, not out of a Renode model.

This is the reference example from KAN-231, milestone 1: the smallest flow that
proves the mechanism before an accelerator or a whole SoC is swapped to RTL.

## What runs

| Piece | Exactly what | Pinned by |
| --- | --- | --- |
| Renode | 1.16.1 (IntegrationLibrary 3.0) | `crucible.lock` (sha256 `56914234…`) |
| Verilator | 5.047.0 | `crucible.lock` (sha256 `d06e1317…`) |
| RTL and C++ bridge | `samples/apb3uart` from [antmicro/renode-verilator-integration](https://github.com/antmicro/renode-verilator-integration), MIT | `upstream.env` (commit `c9692ca3`) |

The upstream sources are fetched, not copied into this repository. The build
refuses any commit other than the pinned one, and refuses a modified checkout.

## Prerequisites

- **Platform:** Linux x86_64. Nothing else has been measured.
- **Crucible:** `igny`, measured on 0.0.7b95.
- **Host tools** (Crucible does not ship them): `cmake`, `make`, a C++ compiler
  (`c++`), `perl`, `python3`, `git` and `timeout`. `build.sh` checks for them
  and names any that are missing.
- **Network:** a first build fetches the upstream commit from GitHub (about 0.5 MB).

## Run it

```sh
igny workspace sync              # install the two locked tools
igny run ./scripts/build.sh      # verilate the UART into output/apb3uart/libVtop.so
igny run ./scripts/smoke.sh      # run it under Renode and judge the result
```

Always launch the scripts through `igny run`, which puts the locked Renode and
Verilator on `PATH`. Run directly, they stop and tell you so. `build.sh` also
refuses if the bound versions differ from `crucible.lock`.

To watch it, or to drive the UART yourself from the Renode monitor:

```sh
igny run renode --disable-xwt --plain --console -e 'include @scripts/uart_cosim.resc'
(apb3uart-cosim) uart WriteChar 0x21
(apb3uart-cosim) sysbus ReadDoubleWord 0x40000000
0x00010021
```

## What the smoke proves

[`scripts/uart_cosim.resc`](scripts/uart_cosim.resc) maps the co-simulated UART
at `0x40000000`, resets it and reads seven registers back from the RTL:

| Read | Register | Value | Meaning |
| --- | --- | --- | --- |
| After reset | STATUS `0x04` | `0x00200000` | TX FIFO has 32 free slots; interrupts off |
| Both interrupts enabled | STATUS | `0x00200103` | Enables set; TX-empty interrupt pending |
| RX interrupt only | STATUS | `0x00200002` | |
| Interrupts disabled | STATUS | `0x00200000` | |
| Before any byte | DATA `0x00` | `0x00000000` | RX not valid |
| After Renode sends `A` | DATA | `0x00010041` | RX valid (bit 16) + `0x41` |
| After Renode sends `Z` | DATA | `0x0001005A` | RX valid + `0x5A` |

Renode exits 0 even when the co-simulated model fails to load, so the exit
status proves nothing. [`scripts/check_uart_log.py`](scripts/check_uart_log.py)
passes a run only when all of these hold:

- all seven labelled reads match, in order;
- the script reached its end marker;
- Renode logged no `[ERROR]`, monitor error or `Operation timeout`.

`smoke.sh` runs three cases and succeeds only if each gives its expected result:

| Case | Expected | Why |
| --- | --- | --- |
| The real model | pass | The demo works |
| The same script with a missing model | reject | A model that failed to load cannot pass |
| The real log, judged against a wrong `Z` byte | reject | The checker compares values, not just shape |

Logs land in `output/smoke/`. The checker has its own unit tests:
`python3 -m unittest discover -s tests`.

## Not covered

- **Other platforms:** Windows and macOS are unmeasured.
- **Other upstream samples:** the AXI RAM sample builds and returns data but
  reports `Operation timeout` on every write with this pair. That is tracked
  separately and is not claimed here.
- **Newer tools:** the Renode 1.17.0 / Verilator 5.052 pairing is unmeasured.
- **`igny run sim`:** no flow is shipped. Native flows crash on 0.0.7b95
  (CRU-159), so this demo uses `igny run` with individual tools and scripts.
- **Portability of the model:** `libVtop.so` is built on your machine with your
  compiler. It is a local build output, not a distributable artifact.
- **Timing:** this demo checks register values and received bytes only. It
  makes no claim about cycle accuracy.
