PYTHON ?= python3
.PHONY: baseline test test32 lint synth
baseline:
	$(PYTHON) scripts/regress.py --baseline
test:
	$(PYTHON) scripts/regress.py
test32:
	$(PYTHON) scripts/regress.py --depth 32
lint:
	verilator --lint-only -Wall --top-module rv32_ooo rtl/*.sv
synth:
	yosys -s synthesis/generic.ys > build/synthesis.log
