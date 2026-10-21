# Tool setup and reproducibility

The base simulation uses Python 3 and Icarus Verilog (`iverilog` and `vvp`). Python
requires no packages. Run `make test` from the repository root. `make baseline`
uses the same tools. The scripts create `build/` automatically.

Additional stages require the following executable names on PATH:

| Stage | Required tools | Version used here |
|---|---|---|
| Core/unit simulation | `iverilog`, `vvp`, `python3` | Icarus 12.0; Python 3.12 |
| Second simulator / RTL lint | `verilator`, host C++ compiler and make | Verilator 5.044 |
| Generic synthesis | `yosys` and its ABC support | Yosys 0.57 |
| GNU assembly/encoding | `riscv64-unknown-elf-as`, `-ld`, `-objcopy` | Exact assembler banner in `results/encoding.json` |
| External semantic check | `qemu-system-riscv32` | QEMU 10.0.2 |
| Optional technology mapping | Yosys plus a supplied Liberty library | Not executed |
| Optional STA | `sta`, mapped netlist and matching Liberty | Not installed / not executed |

Install these tools using their official distribution or your platform package
manager, ensuring that the RISC-V binutils support `-march=rv32im -mabi=ilp32`
and the `elf32lriscv` linker emulation. The executable prefix can be 64-bit while
still supporting 32-bit object files. The existing environment already had all
functional-verification and generic-synthesis tools; no dependency installation
was needed for the reported runs.

`make check` is the complete sequential validation entry point. The QEMU stage
creates a local Unix debugger socket and can require sandbox approval. It loads
no guest operating system and contacts no external service. If a tool is absent,
run only available stages and mark the others **not run**; do not substitute old
result files as evidence of a new successful execution.

Detailed simulation failures stop the runner and are recorded in
`results/last_failure.json`; batch regression logs are in `build/regression_*.log`.
All stimulus seeds and configuration flags are recorded in the JSON reports.
Use `--only <test-name>` to reproduce a failing directed test, or
`--seeds N` to reproduce the first N deterministic random programs.

The current test flow initializes data RAM to zero and holds instruction memory
immutable. The flat assembly workflow does not implement a general ELF loader.
See `docs/interfaces.md` before integrating a different memory subsystem.
