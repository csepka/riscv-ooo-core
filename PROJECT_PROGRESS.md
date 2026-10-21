# Project progress

## Verified delivery — 2026-10-21

Repository: `/Users/christophersepka/Desktop/RISC-V_proj/riscv-ooo-core`.
Branch: `feat/rv32-ooo`. The supplied README-only repository and original commit
`996eeaa` were preserved. No remote push or PR was requested or performed.

Verified milestones:

* `f1dc7dc`: independent Python ISA oracle, sequential RV32I RTL baseline, initial
  architecture contracts and 37-test first checkpoint.
* `c33d57e`: genuine RV32I OoO execution, ROB renaming, recovery, conservative
  memory, assertions and independently checked caches.
* `f516e78`: iterative RV32M path, three result broadcasts, complete configuration
  matrix, QEMU/GNU independent checks and generic synthesis evidence.
* Final documentation commit: measured benchmarks, runnable README/Makefile,
  interfaces, review, physical-flow limitations, saved execution evidence and
  ENGINEERING_MASTERY.md with 56 detailed answered interview questions.

## Implemented architecture

Single-dispatch/single-retirement RV32IM; 16/32-entry circular ROB value renaming;
architectural register file and rename map; ROB-integrated reservation stations;
oldest-ready integer and M selection; one 32-step multiply/divide operation;
three completion broadcasts; in-order precise trap-to-halt retirement; PC+4
prediction with retirement recovery; stale fetch response draining; synchronous
M cancellation; strongly ordered head-only ROB-integrated memory tracking;
optional 16-word direct-mapped write-through caches. FAST_FETCH retains both the
measured earlier frontend and the improved consume/refill behavior.

## Final evidence

| Executed check | Result |
|---|---|
| Icarus full matrix | 832 program runs passed, zero failed |
| Independent Verilator simulation | 54 program runs passed, zero failed |
| Final documented `make test` smoke | 54 program runs passed, zero failed |
| M arithmetic | 4,896 vectors passed |
| M cancellation | 1 check passed |
| Cache unit configurations | 1,009 transactions each at 8/16/32 lines; 3,027 total |
| GNU encoding/relocation | 50 programs, 4,516 matching instructions |
| QEMU 10.0.2 oracle cross-check | 2,113 cases across 46 normal instruction mnemonics |
| Benchmarks | 56 independently checked runs |
| GNU-assembled Fibonacci example | Passed; 64 successful instructions plus EBREAK event |
| Strict RTL lint | 7 configurations passed |
| Generic flattened synthesis | Baseline, OoO16, OoO32 and cache16 passed |

The measured demonstration completes younger PC 08 at cycle 11 and older PC 04
at cycle 39. Retirement remains PC 04 at cycle 41 followed by PC 08 at cycle 42.
See `docs/execution_evidence.md` and its saved trace.

Generic cells / bit flip-flops: baseline 10,432 / 1,845; OoO16 41,029 / 6,452;
OoO32 70,966 / 11,113; standalone cache16 2,710 / 1,151. These are not technology
area figures. Main delayed-memory benchmarks give OoO16 with caches roughly
0.040–0.193 IPC. Several workloads favor the sequential baseline; all regressions
are retained in `docs/performance.md`. A later RTL edit only corrected the header
comment from two to three completion broadcasts; full-matrix and synthesis JSON
hashes identify the behavioral implementation before that comment correction.

## Physical-design boundary

OpenROAD, OpenSTA, Magic and KLayout were not found. No Sky130 PDK was found in
the checked locations. Docker CLI exists but its daemon socket is absent.
Standard-cell area, critical paths, Fmax, floorplan, placement, CTS, routing,
DRC/LVS and GDSII are **not run**. Optional supplied-Liberty mapping and STA
preparation are in `synthesis/technology.py` and `physical_design/`; their example
constraints are not achieved timing. See `docs/physical_design.md`.

## Remaining limitations and next justified milestones

1. Add an official architectural-suite integration and formal queue/tag/recovery
   proofs. Current finite checks do not constitute ISA certification.
2. Improve the measured taken-branch bottleneck with a predictor and explicit
   recovery/checkpoint design; verify all new speculative state.
3. Introduce a separately verified LSQ permitting safe earlier loads, including
   byte-accurate forwarding and replay before any unresolved-store speculation.
4. Improve fetch buffering/latency before considering dual-wide rename/retirement.
5. Supply a legal PDK, standard-cell library and physical tools; execute and record
   each physical stage under explicit constraints.

There is no separate PRF/free list, load speculation/replay, forwarding LSQ,
privileged CSR/interrupt platform, dual dispatch, instruction coherence or
self-modifying-code support. No VERA reference or historical three-stage core
was supplied, so no fidelity or historical performance comparison is claimed.

## Resume commands and artifacts

Start with this file, README.md, docs/rtl_review.md, current Git status and logs.
Do not restart completed hardware. `make check` runs the complete sequential
validation flow. Individual targets are documented in README. QEMU's local Unix
debugger socket requires permission outside this restricted sandbox; it was
approved and successfully executed. All Python tooling uses the standard library.

Tracked `results/` reports and `docs/traces/` are durable evidence. `build/` holds
regenerable executables, vectors, netlists and logs. Smoke targets use separate
report names so they do not overwrite the full-matrix evidence. If a future run
fails, resolve the failure before presenting a previous report as current success.
