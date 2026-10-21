# riscv-ooo-core

Original educational RV32 CPU project. The first verified milestone is a
sequential RV32I RTL baseline, independently checked against a Python interpreter.
The OoO design contract is in [docs/ooo_microarchitecture_spec.md](docs/ooo_microarchitecture_spec.md).

Run `make baseline` with Python 3 and Icarus Verilog 12 installed. No Python
packages are required. The runner assembles directed/seeded programs, simulates
RTL with memory backpressure and delayed responses, compares every retirement,
and writes JSON results under `results/` and detailed traces under `build/`.

See [docs/architecture_plan.md](docs/architecture_plan.md) for ISA, interface and
exception contracts. This is not a privileged RISC-V platform or a compliance
claim. No VERA reference or historical three-stage processor was supplied.

License recommendation: Apache-2.0 for newly authored code. No license grant is
assumed on the user's behalf; choose/add a LICENSE before public redistribution.
