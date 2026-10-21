# Measured out-of-order execution evidence

Generated from `docs/traces/final_ooo.trace` by `scripts/report.py`.

Command: `python3 scripts/regress.py --only ooo --output execution_demo.json`.

| PC | Instruction | Execution completion cycle | Retirement event cycle |
|---|---|---:|---:|
| 0x00 | `lw x1,0(x0)` | memory path; not on ALU/M trace | 40 |
| 0x04 | `add x2,x1,x1` | 39 | 41 |
| 0x08 | `addi x3,x0,7` | 11 | 42 |
| 0x0c | `addi x4,x0,11` | 14 | 43 |
| 0x10 | `add x5,x3,x4` | 17 | 44 |
| 0x14 | `sw x5,4(x0)` | memory path; not on ALU/M trace | 92 |
| 0x18 | `ebreak` | 25 | 93 |

PC 08 completes at cycle 11, before older PC 04 at cycle 39.
PC 04 retires at cycle 41 and PC 08 at cycle 42, preserving program order.
ALU/M completion lines are sampled at rising edges using the most recent falling-edge
cycle count; registered retirement lines are observed at the following falling edge.
Compare ordering directly; the display-edge convention is part of the trace format.

The load holds up its consumer while independent younger arithmetic finishes.
EBREAK also executes speculatively but halts only at head. The checker independently
verifies every retirement and the final stored word (18 at byte address 4).

```text
E 11 00000008
E 14 0000000c
E 17 00000010
E 25 00000018
E 39 00000004
R 40 00000000 00002083 1 00000000 1 00000000 00000000 0 0 0
R 41 00000004 00108133 2 00000000 0 00000000 00000000 0 0 0
R 42 00000008 00700193 3 00000007 0 00000000 00000000 0 0 0
R 43 0000000c 00b00213 4 0000000b 0 00000000 00000000 0 0 0
R 44 00000010 004182b3 5 00000012 0 00000000 00000000 0 0 0
R 92 00000014 00502223 0 00000000 1 00000004 00000012 f 0 0
R 93 00000018 00100073 0 00000000 0 00000000 00000000 0 1 3
```
