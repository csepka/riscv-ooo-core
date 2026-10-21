#!/usr/bin/env python3
"""Opt-in cell-library mapping. Not run without a user-supplied Liberty library."""
import os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
lib=Path(os.environ.get('LIBERTY','')).expanduser()
if not lib.is_file():raise SystemExit('Set LIBERTY to an accessible standard-cell .lib file. No library is bundled.')
depth=int(os.environ.get('ROB_DEPTH','16'))
if depth not in (16,32):raise SystemExit('ROB_DEPTH must be 16 or 32')
# Yosys script quoting is separate from shell quoting; no shell invocation here.
def quoted(path):return '"'+str(path).replace('\\','\\\\').replace('"','\\"')+'"'
build=ROOT/'build';build.mkdir(exist_ok=True)
commands=['read_verilog -sv '+' '.join(quoted(p) for p in sorted((ROOT/'rtl').glob('*.sv'))),f'chparam -set ROB_DEPTH {depth} rv32_ooo','hierarchy -check -top rv32_ooo','rename -top synthesized_core','synth -flatten -noabc -top synthesized_core','dffunmap',f'dfflibmap -liberty {quoted(lib)}',f'abc -liberty {quoted(lib)}','clean','check -assert',f'tee -o build/technology_stat.json stat -json -liberty {quoted(lib)}','write_verilog -noattr build/mapped.v']
script=build/'technology.ys';script.write_text('\n'.join(commands)+'\n')
with (build/'technology.log').open('w') as log:subprocess.run(['yosys','-s',str(script)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
print('Mapped netlist: build/mapped.v. Review mapping log and library area; timing is a separate step.')
