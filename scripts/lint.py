#!/usr/bin/env python3
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];rtl=[str(p) for p in sorted((ROOT/'rtl').glob('*.sv'))];runs=[]
for top,params in [('rv32_baseline',[]),('rv32_ooo',['-GROB_DEPTH=16']),('rv32_ooo',['-GROB_DEPTH=32']),('rv32_cache',['-GLINES=8']),('rv32_cache',['-GLINES=16']),('rv32_cache',['-GLINES=32']),('rv32_muldiv',[])]:
 cmd=['verilator','--lint-only','-Wall','--top-module',top,*params,*rtl];p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
 if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 runs.append(dict(top=top,parameters=params,status='pass'));print('PASS lint',top,*params)
(ROOT/'results/lint.json').write_text(json.dumps(dict(tool=subprocess.check_output(['verilator','--version'],text=True).strip(),passed=len(runs),failed=0,configurations=runs),indent=2)+'\n')
