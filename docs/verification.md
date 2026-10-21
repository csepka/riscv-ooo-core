# Verification

The Python instruction-level interpreter in `verification/isa.py` is independent
of the RTL. It decodes raw machine instructions and compares PC, instruction,
register writes, memory effects and traps at retirement. The hand assembler uses
labels and instruction tuples. No RTL logic is imported by the interpreter.

`make baseline` passes 17 directed and 20 seeded random programs (37 tests).
The sequential RTL baseline passed before OoO RTL implementation began. Its
results are saved in `results/baseline.json`. This is a project-local oracle,
not an external ISA compliance suite. Both implementations can still share a
specification misunderstanding; cross-checking an external model is future work.

The memory responder adds deterministic random request backpressure and variable
load/store response delay. The testbench checks blocked request stability,
single-outstanding contracts and timeouts. Detailed command/configuration and
subsequent OoO verification will be recorded as the implementation advances.
