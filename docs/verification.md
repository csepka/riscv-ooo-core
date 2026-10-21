# Verification results

The independent Python ISA interpreter compares every architectural event: PC,
instruction, destination/value, memory effect and trap cause. It does not import
RTL scheduling logic. Final external data memory is also compared byte for byte.

## Executed checks

| Check | Passed | Failed |
|---|---:|---:|
| Icarus program/configuration matrix | 832 | 0 |
| Verilator whole-core programs | 54 | 0 |
| M-unit arithmetic vectors | 4896 | 0 |
| M-unit cancellation check | 1 | 0 |
| Cache transactions (1,009 at each of 8/16/32 lines) | 3,027 | 0 |
| QEMU single-step oracle cross-check cases | 2113 | 0 |
| GNU encoding/relocation programs (4,516 instructions) | 50 | 0 |
| Strict RTL lint configurations | 7 | 0 |
| Generic synthesis configurations | 4 | 0 |
| Independently checked benchmark runs | 56 | 0 |
| GNU-assembled Fibonacci program | 1 | 0 |

These categories count different kinds of checks and are intentionally not added
into one misleading test total. See the JSON artifacts for individual cases.

## Program matrix

| Configuration | Program runs |
|---|---:|
| baseline | 134 |
| ooo16 | 134 |
| ooo32 | 134 |
| ooo16_cache | 134 |
| ooo32_cache | 134 |
| ooo16_slow | 54 |
| ooo32_slow | 54 |
| ooo16_legacy | 54 |

The five main configurations each run 30 directed programs, 100 seeded random
programs and four active-reset programs. The delayed-memory and legacy-fetch
configurations use 20 random seeds each. Verilator runs the 54-program default
subset as a second implementation of the simulator. Differences in testbench
scheduling can change cycle counts; architectural events must still match.

## Assertion coverage in the Icarus matrix

| Observed event | Count |
|---|---:|
| simultaneous | 12807 |
| wraps | 4477 |
| dual_complete | 565 |
| fetch_pending_flush | 2513 |
| fetch_blocked_flush | 707 |
| full | 108086 |
| md_flush_busy | 1762 |
| md_alu_complete | 1221 |
| triple_complete | 5 |

The testbench checks circular interval/count consistency, live older source tags,
youngest rename targets, x0, shadow sequence retirement order, duplicate execution,
completion validity, stable blocked requests and one outstanding transaction.
Full occupancy, wraparound and simultaneous events are counted explicitly.

## Independent checking and scope

`verification/isa.py` is a locally authored sequential oracle. The QEMU 10.0.2
cross-check covers 46 normal RV32IM instruction mnemonics, including M corner
cases and memory effects, using single-step GDB state comparisons. It does not
validate this core’s trap-to-halt interface against a privileged QEMU platform.
Trap causes, fault ordering and wrong-path faults are instead directed RTL tests.
GNU binutils independently verifies instruction encoding and branch relocation.

No official RISC-V architectural certification suite or formal proof has run.
The project provides compliance-oriented instruction/corner checks, not an
unsupported compliance certification. Exhaustive state-space coverage is not claimed.

## Reproduction

```sh
make regression
make verilator-test
make units
make encoding
make qemu
make lint
make synth
make benchmarks
make reports
```

Python 3 uses only the standard library. Icarus 12, Verilator 5.044, Yosys 0.57,
GNU RISC-V binutils and QEMU 10.0.2 were used. QEMU needs permission to bind its
local Unix debugger socket; no external network service is involved.

Generated images, vectors, logs and traces are in ignored `build/`. Source tests
and machine-readable successful reports are tracked. Timeouts abort simulation;
failures raise an error, and the direct runner also writes `results/last_failure.json`.
A future failed run must not be represented by an older successful report.
