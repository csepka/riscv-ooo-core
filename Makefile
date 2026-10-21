PYTHON ?= python3
.PHONY: test baseline test32 cache-test regression verilator-test units encoding qemu lint synth benchmarks reports check technology-synth sta

test:
	$(PYTHON) scripts/regress.py --output smoke_ooo16.json
baseline:
	$(PYTHON) scripts/regress.py --baseline --output smoke_baseline.json
test32:
	$(PYTHON) scripts/regress.py --depth 32 --output smoke_ooo32.json
cache-test:
	$(PYTHON) scripts/regress.py --cache --output smoke_cache.json
regression:
	$(PYTHON) scripts/full_regression.py
verilator-test:
	$(PYTHON) scripts/regress.py --sim verilator --seeds 20 --output verilator16.json
units:
	$(PYTHON) scripts/unit_tests.py
encoding:
	$(PYTHON) scripts/check_encoding.py
qemu:
	$(PYTHON) scripts/qemu_check.py
lint:
	$(PYTHON) scripts/lint.py
synth:
	$(PYTHON) scripts/synthesize.py
benchmarks:
	$(PYTHON) scripts/benchmark.py
reports:
	$(PYTHON) scripts/report.py
check:
	$(MAKE) regression
	$(MAKE) verilator-test
	$(MAKE) units
	$(MAKE) encoding
	$(MAKE) qemu
	$(MAKE) lint
	$(MAKE) synth
	$(MAKE) benchmarks
	$(MAKE) reports
technology-synth:
	$(PYTHON) synthesis/technology.py
sta:
	sta -exit physical_design/timing.tcl
