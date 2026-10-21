#!/usr/bin/env python3
"""Assemble/link a flat .text at PC zero, then independently check its RTL run.
Data memory starts zero; initialized ELF data sections are not loaded by this flow.
"""
import argparse,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('source');ap.add_argument('--baseline',action='store_true');ap.add_argument('--cache',action='store_true');a=ap.parse_args()
build=ROOT/'build/assembly';build.mkdir(parents=True,exist_ok=True)
obj=build/'program.o';elf=build/'program.elf';binary=build/'program.bin';hexfile=build/'program.hex'
for cmd in [['riscv64-unknown-elf-as','-march=rv32im','-mabi=ilp32','-mno-relax','-o',str(obj),a.source],['riscv64-unknown-elf-ld','-m','elf32lriscv','--no-relax','-Ttext=0','-o',str(elf),str(obj)],['riscv64-unknown-elf-objcopy','-O','binary','--only-section=.text',str(elf),str(binary)]]:
 subprocess.run(cmd,cwd=ROOT,check=True)
raw=binary.read_bytes()
if not raw or len(raw)%4:raise SystemExit('Expected nonempty, 4-byte-aligned RV32IM text')
hexfile.write_text(''.join(f'{int.from_bytes(raw[i:i+4],"little"):08x}\n' for i in range(0,len(raw),4)))
subprocess.run([sys.executable,'scripts/regress.py','--program',str(hexfile),'--output','assembly_example.json',*(['--baseline'] if a.baseline else []),*(['--cache'] if a.cache else [])],cwd=ROOT,check=True)
