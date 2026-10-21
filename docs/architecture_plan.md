# Architecture and implementation plan

This file preserves the initial design contract and staged plan. The delivered
implementation has progressed to RV32IM and verified caches; see
[PROJECT_PROGRESS.md](../PROJECT_PROGRESS.md) for completed milestones and limits.

This repository started from the supplied README-only Git repository. There is no
historical three-stage CPU here and no identifiable VERA architectural reference.
The implementation is a conventional, original educational OoO design.

## Contract fixed before implementation

* Little-endian RV32I, 32 integer registers, x0 hardwired to zero, reset PC 0.
  RV32M, compressed instructions, privileged mode and CSRs are initially excluded.
* Separate instruction and data ports, each allowing one outstanding request.
  A request transfers on valid && ready. Its response arrives on a later cycle
  as a one-cycle valid pulse; the core always accepts responses. Payload must
  remain stable while a request is blocked. Responses are ordered and not
  cancellable. Reset must also reset the attached memory/adapter.
* Instruction requests are aligned byte addresses. Data requests use aligned
  word addresses, a write flag, four byte enables, and lane-shifted write data.
  Read responses supply the entire word. Error responses report access faults.
* Architectural loads/stores must be naturally aligned; instruction targets
  must be four-byte aligned. Misalignment and illegal instructions precisely
  halt at retirement. ECALL and EBREAK also precisely halt. The trap interface
  reports PC and standard RISC-V exception cause; there is no machine trap CSR
  state, handler vector, interrupt support, or claim of platform compliance.
* Retirement exposes PC, raw instruction, destination/value, memory address,
  write data/mask, and exception cause. Differential verification uses this
  interface, not implementation internals.
* Phase one is a non-overlapped, sequential RTL baseline plus an independent
  Python ISA interpreter and small assembler. Later commits add circular ROB
  value renaming, integrated reservation stations, and speculative branches.
* The initial memory queue is the ROB's bounded memory entries. Only the head
  accesses memory. This sacrifices load parallelism but prevents all speculative
  external memory effects. Ready younger arithmetic may execute during a miss.

## Pipeline boundaries

Fetch request -> response buffer -> decode/dispatch -> oldest-ready execution ->
completion/wakeup -> in-order retire. Fetch predicts PC+4. An executed control
transfer records its target; a mismatch redirects at retirement and discards
all younger work. The fetch frontend drains a stale outstanding response before
reusing its port. Thus no finite generation counter is required.

## Planned checkpoints

1. Independently checked sequential baseline with arithmetic, branch and memory.
2. Specify/implement ROB renaming, scheduling, retirement, branch recovery.
3. Directed and seeded differential regression, stalls/reset/wraparound, trace
   proving younger-before-older execution, measurements, lint and synthesis.
4. Independently tested direct-mapped cache adapter and integration measurements.
5. Consider RV32M, wider issue, nonblocking LSQ and physical design only after
   the verified foundation, and only when tools/evidence support them.

No IPC, area, timing or compliance claim is made by this plan.
