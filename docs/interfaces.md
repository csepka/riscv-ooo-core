# RTL integration interface

Both core tops use the same ports. `rv32_ooo` parameters are ROB_DEPTH (supported:
16 or 32) and FAST_FETCH (0 or 1, default 1). The baseline has FAST_FETCH only.
All state changes on the rising edge of `clk`; `reset` is synchronous active high.

| Port group | Meaning |
|---|---|
| `i_req_valid/ready/addr` | Aligned instruction word request, byte address |
| `i_rsp_valid/error/data` | Exactly one later-cycle response for each accepted request |
| `d_req_valid/ready/addr` | Aligned data word request, byte address |
| `d_req_write/wdata/wmask` | Store flag, lane-shifted payload, four active-high byte enables |
| `d_rsp_valid/error/data` | Completion or fault; a load returns the whole aligned word |
| `retire_valid/pc/insn` | Registered architectural event identity |
| `retire_rd/value` | Destination effect; rd zero denotes no architectural register write |
| `retire_mem/addr/data/mask` | Successful load/store record; address is effective byte address |
| `retire_trap/cause` | Precise faulting-head event; not a successfully retired instruction |
| `halted` | Stops after a precise trap until reset |
| `exec_valid/pc` | Integer/branch completion-edge debug event, not the complete retirement interface |
| `debug_occupancy/full/mem_wait/redirect` | Debug only; does not alter memory protocol |

A request transfers only on valid && ready. Once valid is asserted, address and
payload cannot change until transfer (except a global reset). No same-cycle
response to a newly accepted request is supported. Responses have no backpressure:
the core/adapter must always consume the pulse. There is only one accepted request
outstanding per port. A faulting store response must mean **no memory write occurred**.
The core cannot undo responder side effects.

Instruction fetch requests may be speculative. Data requests are head-only and
non-speculative. A redirect drains stale instruction work, and never cancels an
externally accepted transaction. Reset is different: the environment must reset
its pending transaction state along with the core. Architectural registers reset
to zero; external RAM initialization is an environment choice. The main testbench
zeros RAM on reset, while the cache unit test additionally checks preserved RAM.

Cause values implemented: 0 instruction-address misalignment; 1 instruction
access fault; 2 illegal instruction; 3 breakpoint; 4 load-address misalignment;
5 load access fault; 6 store-address misalignment; 7 store access fault; 11 ECALL
under this project's machine-level halt policy. No privilege transition occurs.

The cache adapter adds the same core-side/backing-side protocol around one port.
Only ordinary RAM/immutable instruction storage is covered by its contract. A
cache error neither fills a read line nor updates a write-hit line.
