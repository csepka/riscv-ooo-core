#!/usr/bin/env python3
"""Final supported-configuration matrix. Stop immediately on any failure."""
import json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];(ROOT/'build').mkdir(exist_ok=True)
matrix=[('baseline',['--baseline','--seeds','100']),('ooo16',['--seeds','100']),('ooo32',['--depth','32','--seeds','100']),('ooo16_cache',['--cache','--seeds','100']),('ooo32_cache',['--cache','--depth','32','--seeds','100']),('ooo16_slow',['--seeds','20','--ilatency','7','--latency','80']),('ooo32_slow',['--depth','32','--seeds','20','--ilatency','7','--latency','80']),('ooo16_legacy',['--seeds','20','--legacy-fetch'])]
reports=[]
for name,args in matrix:
 log=ROOT/'build'/f'regression_{name}.log'
 with log.open('w') as f:
  p=subprocess.run([sys.executable,'scripts/regress.py',*args,'--output',name+'.json'],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
 if p.returncode:raise RuntimeError(log.read_text())
 report=json.loads((ROOT/'results'/f'{name}.json').read_text());reports.append(dict(configuration=name,passed=report['passed'],failed=report['failed']))
 print(name,report['passed'],'PASS',flush=True)
(ROOT/'results/regression_summary.json').write_text(json.dumps(dict(passed=sum(r['passed'] for r in reports),failed=0,configurations=reports),indent=2)+'\n')
