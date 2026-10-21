#!/usr/bin/env python3
import json,random,re,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'verification'))
from isa import muldiv
build=ROOT/'build';build.mkdir(exist_ok=True)
r=random.Random(20261020);corners=[0,1,2,3,0x7fffffff,0x80000000,0xfffffffe,0xffffffff,0x10000,0xaaaaaaaa]
vectors=[(f,a,b,muldiv(f,a,b)) for f in range(8) for a in corners for b in corners]
vectors += [(f,a,b,muldiv(f,a,b)) for f,a,b in [(r.randrange(8),r.getrandbits(32),r.getrandbits(32)) for _ in range(4096)]]
(build/'muldiv.txt').write_text(''.join(f'{f:x} {a:08x} {b:08x} {v:08x}\n' for f,a,b,v in vectors))
def run(cmd):
 p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
 if p.returncode: raise RuntimeError(p.stdout+p.stderr)
 print(p.stdout.strip());return p.stdout
run(['iverilog','-g2012','-s','muldiv_tb','-o','build/muldiv.vvp','rtl/rv32_muldiv.sv','tb/muldiv_tb.sv'])
run(['vvp','build/muldiv.vvp','+vectors=build/muldiv.txt'])
cache_metrics=[]
for lines in (8,16,32):
 run(['iverilog','-g2012','-s','cache_tb','-P',f'cache_tb.LINES={lines}','-o','build/cache_unit.vvp','rtl/rv32_cache.sv','tb/cache_tb.sv'])
 output=run(['vvp','build/cache_unit.vvp'])
 metrics={k:int(v) for k,v in re.findall(r'(hits|hit_cycles|misses|miss_cycles)=(\d+)',output)}
 metrics['lines']=lines;metrics['hit_latency_mean']=metrics['hit_cycles']/metrics['hits'];metrics['miss_latency_mean']=metrics['miss_cycles']/metrics['misses'];cache_metrics.append(metrics)
(ROOT/'results/units.json').write_text(json.dumps(dict(muldiv_vectors=len(vectors),muldiv_flush=1,cache_configurations=[8,16,32],cache_transactions_per_configuration=1009,cache_latency=cache_metrics,failed=0),indent=2)+'\n')
