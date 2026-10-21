#!/usr/bin/env python3
"""Cross-check independent oracle semantics against installed QEMU via local GDB.
No guest software, network access, privileged guest code or Python dependencies.
This is not a RISC-V architectural certification suite.
"""
import json,os,random,socket,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'verification'))
from isa import Machine,assemble
BASE=0x80000000;DATA=0x80001000
class Qemu:
 def __enter__(self):
  self.tmp=tempfile.TemporaryDirectory(prefix='rv32-qemu-');path=self.tmp.name+'/gdb.sock'
  self.proc=subprocess.Popen(['qemu-system-riscv32','-M','virt','-cpu','rv32','-m','16M','-bios','none','-display','none','-monitor','none','-serial','none','-S','-gdb',f'unix:{path},server=on,wait=off'],stderr=subprocess.PIPE)
  for _ in range(200):
   if os.path.exists(path):break
   if self.proc.poll() is not None:raise RuntimeError(self.proc.stderr.read().decode())
   time.sleep(.01)
  self.sock=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);self.sock.settimeout(5);self.sock.connect(path)
  self.command('qSupported');return self
 def command(self,text):
  payload=text.encode();self.sock.sendall(b'$'+payload+b'#'+f'{sum(payload)%256:02x}'.encode())
  while self.sock.recv(1)!=b'$':pass
  response=bytearray()
  while True:
   c=self.sock.recv(1)
   if not c:raise RuntimeError('QEMU disconnected')
   if c==b'#':break
   response.extend(c)
  checksum=self.sock.recv(2)
  assert int(checksum,16)==sum(response)%256,'GDB checksum'
  self.sock.sendall(b'+');reply=response.decode()
  if reply.startswith('E'):raise RuntimeError(f'GDB error {reply}: {text[:60]}')
  return reply
 def write(self,addr,data):
  assert self.command(f'M{addr:x},{len(data):x}:{data.hex()}')=='OK'
 def step(self,word,regs,memory):
  self.write(BASE,word.to_bytes(4,'little'));self.write(DATA,memory)
  payload=b''.join(x.to_bytes(4,'little') for x in regs+[BASE])
  assert self.command('G'+payload.hex())=='OK'
  assert self.command('s').startswith('T05')
  raw=bytes.fromhex(self.command('g'))
  values=[int.from_bytes(raw[i:i+4],'little') for i in range(0,132,4)]
  data=bytes.fromhex(self.command(f'm{DATA:x},{len(memory):x}'))
  return values[:32],values[32],data
 def __exit__(self,*args):
  self.sock.close();self.proc.terminate();self.proc.wait(timeout=5);self.proc.stderr.close();self.tmp.cleanup()

def main():
 r=random.Random(731);cases=[]
 ops=['add','sub','sll','slt','sltu','xor','srl','sra','or','and','mul','mulh','mulhsu','mulhu','div','divu','rem','remu']
 for op in ops:
  for _ in range(32):cases.append(((op,3,1,2),r.getrandbits(32),r.getrandbits(32)))
 for op in ['addi','slti','sltiu','xori','ori','andi','slli','srli','srai']:
  for _ in range(32):cases.append(((op,3,1,r.randrange(32) if op.endswith(('lli','rli','rai')) else r.randrange(-2048,2048)),r.getrandbits(32),0))
 for op in ['lui','auipc']:
  for _ in range(32):cases.append(((op,3,r.randrange(1<<20)),0,0))
 for op in ['beq','bne','blt','bge','bltu','bgeu']:
  for a,b in [(0,0),(1,2),(2,1),(0xffffffff,1),(0x80000000,0x7fffffff)]:
   for off in [-32,4,8,64]:cases.append(((op,1,2,off),a,b))
 for op in ['lb','lbu','lh','lhu','lw','sb','sh','sw']:
  align=4 if op in ('lw','sw') else 2 if op in ('lh','lhu','sh') else 1
  for _ in range(32):cases.append(((op,3,1,0),DATA+r.randrange(64//align)*align,0))
 for off in [-32,4,8,64]:cases.append((('jal',3,off),0,0))
 for off in [0,1,4,5]:cases.append((('jalr',3,1,off),BASE+16,0))
 corners=[0,1,2,3,0x7fffffff,0x80000000,0xfffffffe,0xffffffff,0x10000,0xaaaaaaaa]
 for op in ops[10:]:
  for a in corners:
   for b in corners:cases.append(((op,3,1,2),a,b))
 cases.append((('fence',),0,0))
 counts={}
 with Qemu() as q:
  for item,a,b in cases:
   regs=[0]+[r.getrandbits(32) for _ in range(31)];regs[1]=a;regs[2]=b
   memory=bytes(r.getrandbits(8) for _ in range(64));word=assemble([item])[0]
   m=Machine([word],code_base=BASE,memory_base=DATA);m.reg=regs.copy();m.mem[:64]=memory
   event=m.step();assert not event['trap'],(item,event)
   got_regs,got_pc,got_mem=q.step(word,regs,memory)
   assert got_regs==m.reg and got_pc==m.pc and got_mem==m.mem[:64],f'QEMU mismatch {item} a={a:x} b={b:x}\nQEMU {got_regs}, PC {got_pc:x}\nOracle {m.reg}, PC {m.pc:x}'
   counts[item[0]]=counts.get(item[0],0)+1
 report=dict(reference=subprocess.check_output(['qemu-system-riscv32','--version'],text=True).splitlines()[0],passed=len(cases),failed=0,opcodes=counts,scope='Independent oracle cross-check: single-step RV32IM normal execution and memory; trap semantics excluded')
 (ROOT/'results/qemu.json').write_text(json.dumps(report,indent=2)+'\n');print(f'PASS QEMU {len(cases)} cases, {len(counts)} instruction mnemonics')
if __name__=='__main__':main()
