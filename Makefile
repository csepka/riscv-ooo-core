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
cache-test:
	mkdir -p build
	iverilog -g2012 -s cache_tb -o build/cache_unit.vvp rtl/rv32_cache.sv tb/cache_tb.sv
	vvp build/cache_unit.vvp
	$(PYTHON) scripts/regress.py --cache
