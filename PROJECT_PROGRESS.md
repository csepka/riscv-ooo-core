# Project progress

## Current verified state — 2026-10-21

Repository: `/Users/christophersepka/Desktop/RISC-V_proj/riscv-ooo-core`.
Branch: `feat/rv32-ooo`. Existing initial commit was preserved.
Milestones: `f1dc7dc` independently checked sequential RV32I baseline;
`c33d57e` verified RV32I OoO core, branch recovery and caches.
RV32IM/measurement/documentation work is currently being finalized for commit.

Implemented and tested: full unprivileged RV32IM instruction set under the
explicit trap-to-halt policy; 16/32-entry ROB value renaming and integrated
reservation stations; independent integer, iterative multiply/divide and
head-memory execution paths; three completion broadcasts; in-order retirement;
PC+4 speculation and retirement recovery; safe fetch draining and M cancellation;
strongly ordered ROB-integrated memory queue; optional direct-mapped caches.
No separate PRF/free list, speculative load bypass, forwarding LSQ, CSR/interrupt
platform, dual dispatch or self-modifying-code support is claimed.

## Completed validation

* Final Icarus matrix: **832 program runs passed, zero failed**, across baseline,
  16/32-entry cores, cached variants, delayed memory and legacy fetch mode.
* Independent Verilator simulation: **54 program runs passed, zero failed**.
* M unit: **4,896 arithmetic vectors and one cancellation check passed**.
* Cache: **1,009 transactions each at 8/16/32 lines passed** (3,027 total).
* GNU binutils: **50 programs / 4,516 instructions match the local assembler**.
* QEMU 10.0.2: **2,113 cases / 46 instruction mnemonics agree with the independent
  oracle**; these are normal-execution checks, not official certification.
* Strict RTL lint: **seven module/configuration runs passed**.
* Generic flattened Yosys synthesis and connectivity/latch checks passed for
  baseline, OoO16, OoO32 and cache16. Generic cells / flip-flop bits:
  baseline 10,432 / 1,845; OoO16 41,029 / 6,452; OoO32 70,966 / 11,113;
  standalone cache16 2,710 / 1,151. No technology area or timing is claimed.

All figures have machine-readable reports in `results/`. The hardware hash in
these reports identifies the tested RTL. The engineering guide now covers all
modules and contains 56 answered architecture questions.

## Work currently in progress / resume here

1. Six-configuration performance benchmark matrix is running via
   `python3 scripts/benchmark.py`; examine `results/benchmarks.json` and
   `build/bench_*.log` before rerunning it.
2. Generate final performance, execution-evidence, verification and physical
   feasibility reports; update README and Makefile to expose all flows.
3. Review evidence and document remaining limitations, then commit the verified
   RV32IM milestone and final documentation. Do not restart implemented hardware.

OpenROAD, OpenSTA, Magic and KLayout were not found. No Sky130 PDK was found in
the checked locations. Docker CLI exists but its daemon socket is absent.
Physical stages, standard-cell area, critical paths, Fmax and GDSII are not run.

## Useful commands

`python3 scripts/full_regression.py`; `python3 scripts/unit_tests.py`;
`python3 scripts/check_encoding.py`; `python3 scripts/qemu_check.py`;
`python3 scripts/lint.py`; `python3 scripts/synthesize.py`;
`python3 scripts/benchmark.py`.
QEMU's local Unix debugger socket requires execution outside the restricted
sandbox; this was approved and the full cross-check successfully executed.
