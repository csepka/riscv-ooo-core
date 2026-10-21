# riscv-ooo-core

A synthesizable, single-dispatch **RV32IM out-of-order processor** with 16- or
32-entry ROB value renaming, integrated reservation stations, independent
integer/branch and iterative multiply/divide execution, three completion
broadcasts, and precise in-order retirement. A real sequential RTL baseline and
an independent Python ISA interpreter are included.

Branches predict PC+4 and recover at retirement. Memory entries form a bounded,
strongly ordered queue inside the ROB: only the oldest instruction accesses
memory. Optional direct-mapped instruction/data cache adapters are independently
verified. This project makes those conservative tradeoffs explicit.

## Run it

From this directory, with Python 3 and Icarus Verilog installed:

```sh
make test                       # 54 independently checked OoO16 programs
make regression                 # 832 runs across eight configurations
make units                      # M-unit vectors and cache transactions
make verilator-test             # second-simulator regression
make encoding                   # GNU assembler/relocation cross-check
make qemu                       # independent QEMU semantic cross-check
make lint                       # strict RTL lint for seven configurations
make synth                      # four generic Yosys synthesis configurations
make benchmarks                 # six core/cache configurations + fetch comparison
make reports                    # regenerate documentation from measured JSON
```

`make check` runs these validation stages together. The extended commands require
Verilator and a C++ compiler, Yosys, GNU `riscv64-unknown-elf` binutils and
`qemu-system-riscv32`. Python uses only its standard library. Tested versions and
scope are in [verification.md](docs/verification.md). No network service is needed;
QEMU's local debugger socket must be permitted by the execution environment.

Run the supplied real assembly example:

```sh
python3 scripts/run_assembly.py tests/fibonacci.S
python3 scripts/regress.py --depth 32 --cache --seeds 100
python3 scripts/regress.py --only ooo --output execution_demo.json
```

The flat assembly flow links `.text` at address zero and starts data RAM at zero;
it does not load initialized ELF data sections. Programs should terminate with
EBREAK or ECALL. The testbench has 32 KiB instruction storage and 4 KiB data RAM.
Custom tuple/label programs can also be added to `tests/programs.py`.

## Evidence

| Verification | Result |
|---|---:|
| Icarus program/configuration matrix | 832 passed, 0 failed |
| Verilator whole-core programs | 54 passed, 0 failed |
| Multiply/divide arithmetic vectors | 4,896 passed |
| M-unit cancellation | 1 passed |
| Cache transactions across 8/16/32 lines | 3,027 passed |
| QEMU instruction-semantic cases | 2,113 passed, 46 mnemonics |
| GNU encoding checks | 50 programs, 4,516 matching instructions |
| Independently checked benchmark runs | 56 passed |
| RTL lint / generic synthesis configurations | 7 / 4 passed |

In the [measured OoO trace](docs/execution_evidence.md), younger PC `0x08`
completes at cycle **11**, ahead of stalled older PC `0x04` at cycle **39**.
They retire in order at cycles **41** and **42**. The test asserts that ordering
and independently checks architectural results and final external memory.

The [performance report](docs/performance.md) includes IPC/CPI, branch accuracy,
recovery intervals, occupancy, execution utilization, stalls, cache behavior and
latency. It reports regressions as well as improvements. In the specified delayed
memory benchmark matrix, OoO16 with caches measures approximately **0.040–0.193
IPC** across seven workloads. The sequential baseline wins on several branch/cache
workloads; OoO is not assumed to be universally faster.

Generic flattened synthesis reports **41,029 cells / 6,452 bit flip-flops** for
OoO16 and **70,966 / 11,113** for OoO32, excluding external caches. These are
Yosys generic counts, not physical area. No clock frequency, timing closure,
GDSII, or tapeout readiness is claimed. See [physical_design.md](docs/physical_design.md).

## Design contracts and limitations

* All RV32IM unprivileged instruction mnemonics are implemented, including integer
  multiplication/division corner cases. Aligned little-endian accesses only.
* Faults, ECALL and EBREAK precisely halt and report PC/cause. There is no CSR,
  machine trap-handler, interrupt or privileged execution platform.
* One outstanding request per memory port, with later-cycle ordered responses;
  requests remain stable under backpressure. Reset also resets responders/adapters.
* ROB entries provide speculative value storage; no separate PRF/free list exists.
* No speculative load bypass, store-to-load forwarding/replay, early branch
  recovery, dynamic predictor or dual-wide dispatch/retirement.
* Caches use one-word lines, write-through and no write allocation. Instruction
  memory must remain immutable; no FENCE.I, coherence or cached-MMIO support.
* Finite differential tests and assertions are evidence, not formal proof or an
  official RISC-V architectural compliance certification.

## Project map

| Path | Contents |
|---|---|
| `rtl/` | Core, baseline, fetch, decode, execute, load formatting, M unit and cache |
| `tb/` | Variable-latency memory harness, invariants, unit testbenches |
| `verification/` | Independent interpreter and minimal assembler |
| `tests/` | Directed, random and real assembly programs |
| `benchmarks/` | Reproducible workload definitions |
| `scripts/` | Simulation, independent checks, lint, synthesis, benchmark/report flows |
| `results/` | Machine-readable measured results |
| `synthesis/`, `physical_design/` | Generic flow and unexecuted optional technology/STA preparation |
| `docs/` | Contracts, measured evidence, verification, performance and review |

Read [ENGINEERING_MASTERY.md](ENGINEERING_MASTERY.md) for first-principles
explanations, all major modules, instruction examples, alternatives and **56
answered microarchitecture interview questions**. [PROJECT_PROGRESS.md](PROJECT_PROGRESS.md)
records the verified state and next priorities.

The supplied README-only repository and initial commit were preserved. No VERA
reference was supplied, so this is a conventional original OoO design. No
historical three-stage CPU or third-party proprietary RTL was assumed or copied.

License recommendation: Apache-2.0 for newly authored code. No license grant is
assumed on the owner's behalf; choose and add a LICENSE before redistribution.
