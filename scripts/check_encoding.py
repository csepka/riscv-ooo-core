#!/usr/bin/env python3
"""Check local assembler bytes against GNU binutils, including resolved labels."""
import json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'verification'),str(ROOT/'tests')]
from isa import assemble
from programs import directed,random_program

def source(program):
 lines=['.option norvc','.option norelax','.text','.global _start','_start:']
 for item in program:
  if isinstance(item,str):lines.append(item+':');continue
  op,*a=item
  if op=='raw':line=f'.word {a[0]}'
  elif op in ('ebreak','ecall','fence'):line=op
  elif op in ('lui','auipc'):line=f'{op} x{a[0]}, {a[1]}'
  elif op=='jal':line=f'jal x{a[0]}, '+(a[1] if isinstance(a[1],str) else f'.+({a[1]})')
  elif op in ('beq','bne','blt','bge','bltu','bgeu'):line=f'{op} x{a[0]}, x{a[1]}, '+(a[2] if isinstance(a[2],str) else f'.+({a[2]})')
  elif op in ('lb','lh','lw','lbu','lhu','sb','sh','sw','jalr'):line=f'{op} x{a[0]}, {a[2]}(x{a[1]})'
  elif op in ('addi','slti','sltiu','xori','ori','andi','slli','srli','srai'):line=f'{op} x{a[0]}, x{a[1]}, {a[2]}'
  else:line=f'{op} x{a[0]}, x{a[1]}, x{a[2]}'
  lines.append(line)
 return '\n'.join(lines)+'\n'

def main():
 build=ROOT/'build/encoding';build.mkdir(parents=True,exist_ok=True)
 programs=directed();programs.update({f'random_{i}':random_program(i) for i in range(20)})
 total=0
 for name,program in programs.items():
  asm=build/f'{name}.S';obj=asm.with_suffix('.o');elf=asm.with_suffix('.elf');binary=asm.with_suffix('.bin');asm.write_text(source(program))
  for cmd in [['riscv64-unknown-elf-as','-march=rv32im','-mabi=ilp32','-mno-relax','-o',str(obj),str(asm)],['riscv64-unknown-elf-ld','-m','elf32lriscv','--no-relax','-Ttext=0','-o',str(elf),str(obj)],['riscv64-unknown-elf-objcopy','-O','binary','--only-section=.text',str(elf),str(binary)]]:
   subprocess.run(cmd,check=True,capture_output=True)
  local=b''.join(w.to_bytes(4,'little') for w in assemble(program));gnu=binary.read_bytes()
  assert local==gnu,f'GNU encoding mismatch: {name}'
  total+=len(local)//4
 report=dict(passed=len(programs),instructions=total,failed=0,tool=subprocess.check_output(['riscv64-unknown-elf-as','--version'],text=True).splitlines()[0])
 (ROOT/'results/encoding.json').write_text(json.dumps(report,indent=2)+'\n');print(f'PASS encoding: {len(programs)} programs, {total} instructions')
if __name__=='__main__':main()
