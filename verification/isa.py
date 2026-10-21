"""Independent RV32I assembler and instruction-level interpreter (no RTL imports)."""
MASK = 0xffffffff

def signed(x, bits=32):
    x &= (1 << bits) - 1
    return x - (1 << bits) if x >> (bits-1) else x


def assemble(items):
    labels, pc = {}, 0
    for item in items:
        if isinstance(item, str): labels[item] = pc
        else: pc += 4
    words, pc = [], 0
    for item in items:
        if isinstance(item, str): continue
        op, *a = item
        if op == 'raw': w = a[0]
        elif op in ('ecall', 'ebreak', 'fence'):
            w = {'ecall':0x73, 'ebreak':0x100073, 'fence':0x0ff0000f}[op]
        elif op in ('lui','auipc'):
            rd, imm = a; w = (imm & 0xfffff) << 12 | rd << 7 | (0x37 if op == 'lui' else 0x17)
        elif op == 'jal':
            rd, target = a; v = (labels[target]-pc if isinstance(target,str) else target) & 0x1fffff
            w = ((v>>20)<<31) | ((v>>1)&1023)<<21 | ((v>>11)&1)<<20 | ((v>>12)&255)<<12 | rd<<7 | 0x6f
        elif op in ('beq','bne','blt','bge','bltu','bgeu'):
            r1,r2,target=a; v=(labels[target]-pc if isinstance(target,str) else target)&8191
            f={'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}[op]
            w=(v>>12)<<31 | ((v>>5)&63)<<25 | r2<<20 | r1<<15 | f<<12 | ((v>>1)&15)<<8 | ((v>>11)&1)<<7 | 0x63
        elif op in ('sb','sh','sw'):
            r2,r1,v=a; v &= 4095; f={'sb':0,'sh':1,'sw':2}[op]
            w=(v>>5)<<25 | r2<<20 | r1<<15 | f<<12 | (v&31)<<7 | 0x23
        elif op in ('mul','mulh','mulhsu','mulhu','div','divu','rem','remu'):
            rd,r1,r2=a;f=['mul','mulh','mulhsu','mulhu','div','divu','rem','remu'].index(op)
            w=1<<25 | r2<<20 | r1<<15 | f<<12 | rd<<7 | 0x33
        elif op in ('add','sub','sll','slt','sltu','xor','srl','sra','or','and'):
            rd,r1,r2=a; f={'add':0,'sub':0,'sll':1,'slt':2,'sltu':3,'xor':4,'srl':5,'sra':5,'or':6,'and':7}[op]
            w=(0x20 if op in ('sub','sra') else 0)<<25 | r2<<20 | r1<<15 | f<<12 | rd<<7 | 0x33
        else:
            rd,r1,v=a
            fs={'addi':0,'slti':2,'sltiu':3,'xori':4,'ori':6,'andi':7,'slli':1,'srli':5,'srai':5,'lb':0,'lh':1,'lw':2,'lbu':4,'lhu':5,'jalr':0}
            f=fs[op]; opc=3 if op in ('lb','lh','lw','lbu','lhu') else 0x67 if op=='jalr' else 0x13
            if op=='srai': v |= 0x400
            w=(v&4095)<<20 | r1<<15 | f<<12 | rd<<7 | opc
        words.append(w & MASK); pc += 4
    return words


class Machine:
    def __init__(self, words, memory_bytes=4096, instruction_fault=None, code_base=0, memory_base=0):
        self.words=words; self.mem=bytearray(memory_bytes); self.reg=[0]*32; self.pc=code_base
        self.code_base=code_base;self.memory_base=memory_base
        self.halted=False; self.instruction_fault=instruction_fault

    def step(self):
        pc=self.pc
        index=(pc-self.code_base)//4
        fetch_fault=index<0 or index>=len(self.words) or pc == self.instruction_fault
        ins=0 if fetch_fault else self.words[index]
        opc=ins&127; rd=(ins>>7)&31; f=(ins>>12)&7; r1=(ins>>15)&31; r2=(ins>>20)&31; f7=ins>>25
        a,b=self.reg[r1],self.reg[r2]; imm=signed(ins>>20,12)
        nxt=(pc+4)&MASK; value=0; wr=False; cause=None; addr=0; data=0; mask=0; memop=False
        if fetch_fault: cause=1
        elif opc in (0x37,0x17): value=(ins&0xfffff000)+(pc if opc==0x17 else 0); wr=True
        elif opc==0x6f:
            off=((ins>>31)<<20)|(((ins>>12)&255)<<12)|(((ins>>20)&1)<<11)|(((ins>>21)&1023)<<1)
            nxt=(pc+signed(off,21))&MASK; value=pc+4; wr=True
        elif opc==0x67 and f==0: nxt=(a+imm)&MASK&~1; value=pc+4; wr=True
        elif opc==0x63:
            off=((ins>>31)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&63)<<5)|(((ins>>8)&15)<<1)
            cond={0:a==b,1:a!=b,4:signed(a)<signed(b),5:signed(a)>=signed(b),6:a<b,7:a>=b}
            if f not in cond: cause=2
            elif cond[f]: nxt=(pc+signed(off,13))&MASK
        elif opc==0x33 and f7==1:
            value=muldiv(f,a,b);wr=True
        elif opc in (0x13,0x33):
            rhs=imm&MASK if opc==0x13 else b
            legal=(opc==0x13 and (f not in (1,5) or f7==0 or (f==5 and f7==32))) or (opc==0x33 and (f7==0 or (f7==32 and f in (0,5))))
            if not legal: cause=2
            else:
                shift=rhs&31
                if f==0: value=a-rhs if opc==0x33 and f7==32 else a+rhs
                elif f==1: value=a<<shift
                elif f==2: value=int(signed(a)<signed(rhs))
                elif f==3: value=int(a<rhs)
                elif f==4: value=a^rhs
                elif f==5: value=signed(a)>>shift if f7==32 else a>>shift
                elif f==6: value=a|rhs
                else: value=a&rhs
                wr=True
        elif opc in (3,0x23):
            store=opc==0x23
            off=signed(((ins>>25)<<5)|((ins>>7)&31),12) if store else imm
            addr=(a+off)&MASK; memop=True;offset=addr-self.memory_base
            size={0:1,1:2,2:4,4:1,5:2}.get(f)
            if size is None or (store and f>2): cause=2
            elif addr%size: cause=6 if store else 4
            elif offset<0 or offset+size>len(self.mem): cause=7 if store else 5
            elif store:
                mask=((1<<size)-1)<<(addr&3); data=(b<<((addr&3)*8))&MASK
                self.mem[offset:offset+size]=(b&((1<<(size*8))-1)).to_bytes(size,'little')
            else:
                value=int.from_bytes(self.mem[offset:offset+size],'little')
                if f<4: value=signed(value,size*8)
                wr=True
        elif opc==0x0f and f==0: pass
        elif ins==0x73: cause=11
        elif ins==0x100073: cause=3
        else: cause=2
        if cause is None and nxt&3: cause=0
        value &= MASK
        if cause is not None: wr=False; self.halted=True; mask=0; data=0
        if wr and rd: self.reg[rd]=value
        self.reg[0]=0; self.pc=nxt
        return dict(pc=pc, insn=ins, rd=rd if wr and rd else 0, value=value if wr and rd else 0,
                    mem=int(memop and cause is None), addr=addr if memop and cause is None else 0,
                    data=data if cause is None else 0, mask=mask, trap=int(cause is not None), cause=cause or 0)


def muldiv(f,a,b):
    """ISA math: host arbitrary precision, independent of iterative RTL algorithm."""
    if f==0: return (a*b)&MASK
    if f==1: return ((signed(a)*signed(b))>>32)&MASK
    if f==2: return ((signed(a)*b)>>32)&MASK
    if f==3: return ((a*b)>>32)&MASK
    if b==0: return MASK if f in (4,5) else a
    x,y=(signed(a),signed(b)) if f in (4,6) else (a,b)
    q=abs(x)//abs(y)
    if (x<0)!=(y<0): q=-q
    return (q if f in (4,5) else x-q*y)&MASK
