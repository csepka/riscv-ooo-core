#!/usr/bin/env python3
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'verification'),str(ROOT/'tests')]
from isa import Machine,assemble
from programs import directed,random_program

def run(cmd):
    p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if p.returncode: raise RuntimeError(' '.join(map(str,cmd))+'\n'+p.stdout+p.stderr)
    return p.stdout

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--baseline',action='store_true');ap.add_argument('--seeds',type=int,default=20);ap.add_argument('--depth',type=int,default=16);ap.add_argument('--latency',type=int,default=30);ap.add_argument('--only');args=ap.parse_args()
    build=ROOT/'build';build.mkdir(exist_ok=True)
    name='baseline' if args.baseline else f'ooo{args.depth}'
    image=build/f'{name}.vvp'
    rtl=[str(p) for p in (ROOT/'rtl').glob('*.sv')]
    run(['iverilog','-g2012','-s','core_tb','-P',f'core_tb.DEPTH={args.depth}',*(['-DBASELINE'] if args.baseline else []),'-o',str(image),*rtl,'tb/core_tb.sv'])
    progs=directed();progs.update({f'random_{s}':random_program(s) for s in range(args.seeds)})
    if args.only: progs={k:v for k,v in progs.items() if k==args.only}
    results=[]
    for test,program in progs.items():
        words=assemble(program);hexfile=build/f'{test}.hex';hexfile.write_text(''.join(f'{w:08x}\n' for w in words));trace=build/f'{name}_{test}.trace'
        fault=4 if test=='fetch_fault' else -1
        run(['vvp',str(image),f'+program={hexfile}',f'+trace={trace}',f'+words={len(words)}',f'+latency={args.latency}',f'+ifault={fault}',f'+seed={len(test)*17+1}'])
        m=Machine(words,instruction_fault=fault);retire=[];execution=[];stats=None
        for line in trace.read_text().splitlines():
            p=line.split()
            if p[0]=='R':
                got=dict(zip(['pc','insn','rd','value','mem','addr','data','mask','trap','cause'],[int(x,16 if i in (0,1,3,5,6,7) else 10) for i,x in enumerate(p[2:])]))
                exp=m.step()
                if got!=exp: raise AssertionError(f'{name}/{test} retirement {len(retire)}\nRTL {got}\nREF {exp}\n{trace}')
                retire.append((int(p[1]),got['pc']))
            elif p[0]=='E': execution.append((int(p[1]),int(p[2],16)))
            elif p[0]=='M': stats=list(map(int,p[1:]))
        assert m.halted and stats, f'{test}: missing precise halt/stats'
        cycles,n,occ_sum,occ_max,full,memwait,execs,redirects=stats
        ooo=0
        if test=='ooo':
            executed={pc:cycle for cycle,pc in execution}
            ooo=int(executed[8]<executed[4])
            if not args.baseline: assert ooo, f'No OoO execution: {execution}'
        result=dict(test=test,status='pass',cycles=cycles,retired=n,ipc=n/cycles,cpi=cycles/n,occupancy_mean=occ_sum/cycles,occupancy_max=occ_max,full_cycles=full,memory_wait_cycles=memwait,executions=execs,redirects=redirects,ooo_demo=ooo)
        results.append(result);print(f'{name}/{test}: PASS ({n} retirements, {cycles} cycles)')
    output=ROOT/'results'/f'{name}.json';output.write_text(json.dumps(dict(configuration=vars(args),passed=len(results),failed=0,tests=results),indent=2)+'\n')
    print(f'{len(results)} passed; {output}')
if __name__=='__main__': main()
