#!/usr/bin/env python3
"""Same program, memory service sequence and core settings across comparisons."""
import json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];(ROOT/'build').mkdir(exist_ok=True)
configs=[('baseline',['--baseline']),('ooo16',[]),('ooo32',['--depth','32']),('baseline_cache',['--baseline','--cache']),('ooo16_cache',['--cache']),('ooo32_cache',['--depth','32','--cache'])]
all_results={}
for name,flags in configs:
 outfile='bench_'+name+'.json'
 with (ROOT/'build'/('bench_'+name+'.log')).open('w') as f:
  subprocess.run([sys.executable,'scripts/regress.py','--benchmarks','--ilatency','8','--latency','30',*flags,'--output',outfile],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
 all_results[name]=json.loads((ROOT/'results'/outfile).read_text());print('PASS benchmarks',name,flush=True)
for mode,flag in [('before',['--legacy-fetch']),('after',[])]:
 with (ROOT/'build'/('bench_'+mode+'.log')).open('w') as f:
  subprocess.run([sys.executable,'scripts/regress.py','--benchmarks',*flag,'--output',f'bench_{mode}_frontend.json'],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
(ROOT/'results/benchmarks.json').write_text(json.dumps(dict(configurations={k:v['configuration'] for k,v in all_results.items()},passed=sum(v['passed'] for v in all_results.values())+14,failed=0),indent=2)+'\n')
