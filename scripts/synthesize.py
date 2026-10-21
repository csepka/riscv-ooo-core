#!/usr/bin/env python3
"""Portable generic synthesis only: no library area or physical timing claim."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];build=ROOT/'build';build.mkdir(exist_ok=True)
version=subprocess.check_output(['yosys','-V'],text=True).strip();reports=[]
for label,top,params in [('baseline','rv32_baseline',{}),('ooo16','rv32_ooo',{'ROB_DEPTH':16}),('ooo32','rv32_ooo',{'ROB_DEPTH':32}),('cache16','rv32_cache',{'LINES':16})]:
 script=build/f'synth_{label}.ys';stat=build/f'stat_{label}.json';log=build/f'synth_{label}.log'
 commands=['read_verilog -sv '+' '.join(str(p.relative_to(ROOT)) for p in sorted((ROOT/'rtl').glob('*.sv')))]
 commands += [f'chparam -set {key} {value} {top}' for key,value in params.items()]
 commands += [f'hierarchy -check -top {top}','rename -top synthesized_core','synth -flatten -top synthesized_core','check -assert','select -assert-none t:$_DLATCH_*',f'tee -o {stat} stat -json',f'write_json build/netlist_{label}.json']
 script.write_text('\n'.join(commands)+'\n')
 with log.open('w') as f:subprocess.run(['yosys','-s',str(script)],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
 stats=json.loads(stat.read_text())['design'];cells=stats['num_cells_by_type']
 report=dict(configuration=label,top=top,parameters=params,generic_cells=stats['num_cells'],flip_flop_bits=sum(v for k,v in cells.items() if 'DFF' in k),cells_by_type=cells,unmapped_memories=stats['num_memories'],warnings=[line for line in log.read_text().splitlines() if line.startswith('Warning:')],script=commands,log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
 reports.append(report);print(label,report['generic_cells'],'generic cells,',report['flip_flop_bits'],'flip-flop bits',flush=True)
rtl_hash=hashlib.sha256(b''.join(p.name.encode()+p.read_bytes() for p in sorted((ROOT/'rtl').glob('*.sv')))).hexdigest()
(ROOT/'results/synthesis.json').write_text(json.dumps(dict(tool=version,rtl_sha256=rtl_hash,technology='Yosys generic gates; no physical library',area=None,timing=None,configurations=reports),indent=2)+'\n')
