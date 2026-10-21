# Project progress

## Current state (2026-10-20)

Existing README-only repository preserved; work is on `feat/rv32-ooo`.
Initial reference/baseline milestone is commit `f1dc7dc`.

Implemented: RV32I sequential baseline and independent Python interpreter;
16/32-entry ROB with integrated reservation stations and value renaming;
oldest-ready ALU scheduling; head-only strongly ordered memory accesses;
precise retirement traps; static PC+4 speculation and retirement-time recovery;
uncancellable fetch response draining; optional direct-mapped word-line caches.

Verified before starting RV32M: baseline, OoO16 and OoO32 each pass 128
programs; cached OoO16 passes 48 programs. Structural assertions cover wrap,
full occupancy, simultaneous allocation/retirement and completion collisions.
The younger PC 8 executes at cycle 12, the older dependent PC 4 at cycle 42;
retirements occur in order. Generic Yosys synthesis completed for OoO16, with
one expected array-to-register lowering warning, and no inferred technology
area or timing. Verilator core/cache lint is clean.

## Next work

1. Finish standalone cache checks, commit RV32I OoO/cache milestone.
2. Add a separate iterative multiply/divide unit and RV32M oracle/test coverage.
3. Expand independent encoding/compliance-oriented checks and regression matrix.
4. Reproducible benchmark counters and performance analysis, synthesis for both
   sizes, physical-tool/PDK discovery and exact limitations.
5. Complete README, architecture/verification reports, and ENGINEERING_MASTERY
   including module explanations and at least 50 answered interview questions.

Do not restart completed work or assume external compliance/physical closure.
Commands: `python3 scripts/regress.py --seeds 100`, add `--depth 32`,
`--baseline` or `--cache`. Generated products live in ignored `build/`.
