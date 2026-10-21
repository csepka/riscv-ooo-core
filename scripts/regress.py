#!/usr/bin/env python3
import argparse,hashlib,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'verification'),str(ROOT/'tests')]
from isa import Machine,assemble
from programs import directed,random_program

def run(cmd):
    p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if p.returncode: raise RuntimeError(' '.join(map(str,cmd))+'\n'+p.stdout+p.stderr)
    return p.stdout

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--baseline',action='store_true');ap.add_argument('--seeds',type=int,default=20);ap.add_argument('--depth',type=int,default=16);ap.add_argument('--latency',type=int,default=30);ap.add_argument('--only');ap.add_argument('--program');ap.add_argument('--ilatency',type=int,default=0);ap.add_argument('--output');ap.add_argument('--cache',action='store_true');ap.add_argument('--benchmarks',action='store_true');ap.add_argument('--legacy-fetch',action='store_true');ap.add_argument('--sim',choices=['icarus','verilator'],default='icarus');args=ap.parse_args()
    build=ROOT/'build';build.mkdir(exist_ok=True)
    name='baseline' if args.baseline else f'ooo{args.depth}'
    if args.cache: name+='_cache'
    image=build/f'{name}.vvp'
    rtl=[str(p) for p in (ROOT/'rtl').glob('*.sv')]
    if args.sim=='icarus':
        run(['iverilog','-g2012','-s','core_tb','-P',f'core_tb.DEPTH={args.depth}','-P',f'core_tb.CACHE={int(args.cache)}','-P',f'core_tb.FAST_FETCH={int(not args.legacy_fetch)}',*(['-DBASELINE'] if args.baseline else []),'-o',str(image),*rtl,'tb/core_tb.sv'])
        simulator=['vvp',str(image)]
    else:
        objdir=build/f'verilator_{name}'
        run(['verilator','--binary','--timing','--assert','-Wno-fatal','--top-module','core_tb','-Mdir',str(objdir),f'-GDEPTH={args.depth}',f'-GCACHE={int(args.cache)}',f'-GFAST_FETCH={int(not args.legacy_fetch)}',*(['-DBASELINE'] if args.baseline else []),*rtl,'tb/core_tb.sv'])
        simulator=[str(objdir/'Vcore_tb')]
    progs=directed();progs.update({f'random_{s}':random_program(s) for s in range(args.seeds)})
    progs.update({'reset_load':directed()['ooo'], 'reset_pressure':directed()['pressure'], 'reset_fetch':directed()['branches'], 'reset_md':directed()['md_ooo']})
    if args.benchmarks:
        import importlib.util
        spec=importlib.util.spec_from_file_location('bench_programs',ROOT/'benchmarks/programs.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        progs=module.benchmark_programs()
    if args.program:
        progs={'external_program':[('raw',int(line,16)) for line in Path(args.program).read_text().splitlines() if line.strip()]}
    if args.only: progs={k:v for k,v in progs.items() if k==args.only}
    if not progs: raise ValueError('No programs selected; check --only or --program')
    results=[]
    for test,program in progs.items():
        words=assemble(program);hexfile=build/f'{test}.hex';hexfile.write_text(''.join(f'{w:08x}\n' for w in words));trace=build/f'{name}_{test}.trace'
        fault=4 if test=='fetch_fault' else -1
        reset_at={'reset_load':20,'reset_pressure':100,'reset_fetch':12,'reset_md':20}.get(test,-1)
        latency=max(args.latency,300) if test in ('pressure','dependency_pressure','reset_pressure') else args.latency
        stdout=run([*simulator,f'+program={hexfile}',f'+trace={trace}',f'+words={len(words)}',f'+latency={latency}',f'+ilatency={args.ilatency}',f'+reset_at={reset_at}',f'+ifault={fault}',f'+seed={len(test)*17+1}'])
        m=Machine(words,instruction_fault=fault);retire=[];execution=[];stats=None;actual_mem=bytearray(4096); resets=0;trap_events=0;cache_stats=[0]*5;queue_stats={};memory_stats=[0,0];flushes=[];allocations=[];branch_count=0;branch_misses=0
        for line in trace.read_text().splitlines():
            p=line.split()
            if p[0]=='R':
                got=dict(zip(['pc','insn','rd','value','mem','addr','data','mask','trap','cause'],[int(x,16 if i in (0,1,3,5,6,7) else 10) for i,x in enumerate(p[2:])]))
                exp=m.step()
                if got!=exp: raise AssertionError(f'{name}/{test} retirement {len(retire)}\nRTL {got}\nREF {exp}\n{trace}')
                trap_events+=got['trap']
                retire.append((int(p[1]),got['pc']))
                if got['insn']&127==0x63:
                    branch_count+=1;branch_misses+=int(m.pc!=got['pc']+4)
            elif p[0]=='E': execution.append((int(p[1]),int(p[2],16)))
            elif p[0]=='RESET':
                m=Machine(words,instruction_fault=fault);retire=[];execution=[];resets+=1;flushes=[];allocations=[];branch_count=0;branch_misses=0;trap_events=0
            elif p[0]=='D': actual_mem[int(p[1])]=int(p[2],16)
            elif p[0]=='Q': queue_stats={k:int(v) for k,v in (kv.split('=') for kv in p[1:])}
            elif p[0]=='L': memory_stats=list(map(int,p[1:]))
            elif p[0]=='F': flushes.append((int(p[1]),int(p[2],16)))
            elif p[0]=='A': allocations.append((int(p[1]),int(p[2],16)))
            elif p[0]=='C': cache_stats=list(map(int,p[1:]))
            elif p[0]=='M': stats=list(map(int,p[1:]))
        assert m.halted and stats, f'{test}: missing precise halt/stats'
        assert actual_mem==m.mem, f'{test}: external memory differs from reference (possible wrong-path write)'
        assert resets==int(reset_at>=0), f'{test}: reset did not execute'
        cycles,n,occ_sum,occ_max,full,memwait,execs,redirects=stats
        ooo=0
        if test=='ooo':
            executed={pc:cycle for cycle,pc in execution}
            ooo=int(executed[8]<executed[4])
            if not args.baseline: assert ooo, f'No OoO execution: {execution}'
        coverage={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',stdout.split('COVER')[-1])} if 'COVER' in stdout else {}
        branches=branch_count
        redirect_dispatch=[];redirect_retire=[]
        for cycle,target in flushes:
            for at,pc in allocations:
                if at>cycle and pc==target: redirect_dispatch.append(at-cycle);break
            for at,pc in retire:
                if at>cycle and pc==target: redirect_retire.append(at-cycle);break
        result=dict(test=test,status='pass',cycles=cycles,retirement_events=n,retired=n-trap_events,ipc=(n-trap_events)/cycles,cpi=(cycles/(n-trap_events) if n>trap_events else None),occupancy_mean=occ_sum/cycles,occupancy_max=occ_max,full_cycles=full,memory_wait_cycles=memwait,executions=execs,redirects=redirects,ooo_demo=ooo,coverage=coverage,conditional_branches=branches,branch_misses=branch_misses,branch_accuracy=(1-branch_misses/branches if branches else None),redirect_to_dispatch_mean=(sum(redirect_dispatch)/len(redirect_dispatch) if redirect_dispatch else None),redirect_to_retire_mean=(sum(redirect_retire)/len(redirect_retire) if redirect_retire else None),queue=queue_stats,memory_requests=memory_stats[0],memory_latency_mean=(memory_stats[1]/memory_stats[0] if memory_stats[0] else None),reset_events=resets,cache=dict(zip(["i_hits","i_misses","d_hits","d_misses","writes"],cache_stats)))
        results.append(result);print(f'{name}/{test}: PASS ({n} checked retirement events, {cycles} cycles)')
    output=ROOT/'results'/(args.output or (f'{name}_{args.only}.json' if args.only else f'{name}.json'));output.write_text(json.dumps(dict(configuration=vars(args),command=sys.argv,rtl_sha256=hashlib.sha256(b''.join(p.name.encode()+p.read_bytes() for p in sorted((ROOT/'rtl').glob('*.sv')))).hexdigest(),passed=len(results),failed=0,tests=results),indent=2)+'\n')
    print(f'{len(results)} passed; {output}')
if __name__=='__main__':
    try:
        main()
    except Exception as error:
        (ROOT/'results').mkdir(exist_ok=True)
        (ROOT/'results/last_failure.json').write_text(json.dumps(dict(status='failed',command=sys.argv,error=str(error)),indent=2)+'\n')
        raise
