import random

def directed():
    return {
        'smoke': [('addi',1,0,17),('addi',2,0,-3),('add',3,1,2),('sw',3,0,0),('lw',4,0,0),('beq',3,4,'ok'),('addi',5,0,99),'ok',('addi',0,0,9),('ebreak',)],
        'ooo': [('lw',1,0,0),('add',2,1,1),('addi',3,0,7),('addi',4,0,11),('add',5,3,4),('sw',5,0,4),('ebreak',)],
        'rename': [('addi',1,0,10),('lw',2,0,0),('add',3,1,2),('addi',1,0,20),('add',4,3,1),('add',1,1,4),('addi',0,1,2),('sw',1,0,8),('ebreak',)],
        'branches': [('addi',1,0,8),'loop',('addi',1,1,-1),('beq',1,0,'done'),('bne',1,0,'loop'),('sw',1,0,0),'done',('jal',2,'target'),('sw',2,0,4),('raw',0xffffffff),'target',('auipc',3,0),('addi',3,3,16),('jalr',4,3,0),('sw',4,0,8),('ebreak',)],
        'bytes': [('addi',1,0,-129),('sw',1,0,0),('lb',2,0,0),('lbu',3,0,1),('lh',4,0,0),('lhu',5,0,2),('sb',3,0,2),('sh',2,0,4),('lw',6,0,0),('lw',7,0,4),('fence',),('ebreak',)],
        'signed': [('lui',1,0x80000),('addi',2,0,-1),('slt',3,1,2),('sltu',4,1,2),('srai',5,1,31),('srli',6,1,31),('slli',7,2,31),('sra',8,1,2),('srl',9,1,2),('sub',10,1,2),('sltiu',11,1,-1),('slti',12,1,0),('ebreak',)],
        'pressure': [('lw',1,0,0)]+[('addi',i%30+1,0,i) for i in range(90)]+[('ebreak',)],
        'wrap': [('addi',1,0,50),'loop',('lw',2,0,0),('add',3,2,1),('sw',3,0,0),('addi',1,1,-1),('bne',1,0,'loop'),('ebreak',)],
        'misaligned_load': [('lh',1,0,1),('sw',1,0,0),('ebreak',)],
        'misaligned_store': [('addi',1,0,1),('sw',1,0,2),('ebreak',)],
        'misaligned_jump': [('jal',1,2),('ebreak',)],
        'load_fault': [('lui',1,1),('lw',2,1,0),('ebreak',)],
        'store_fault': [('lui',1,1),('sw',1,1,0),('ebreak',)],
        'illegal': [('raw',0xffffffff),('ebreak',)],
        'bad_shift': [('raw',0x02001093),('ebreak',)],
        'ecall': [('ecall',)],
        'fetch_fault': [('addi',1,0,5),('ebreak',)],
    }

def random_program(seed, count=160):
    r=random.Random(seed); p=[('addi',i,0,r.randrange(-100,101)) for i in range(1,32)]
    alu=['add','sub','sll','slt','sltu','xor','srl','sra','or','and']
    imm=['addi','slti','sltiu','xori','ori','andi']
    for i in range(count):
        rd,a,b=[r.randrange(32) for _ in range(3)]; kind=r.randrange(10)
        if kind<4: p.append((r.choice(alu),rd,a,b))
        elif kind<6: p.append((r.choice(imm),rd,a,r.randrange(-2048,2048)))
        elif kind==6: p.append((r.choice(['slli','srli','srai']),rd,a,r.randrange(32)))
        elif kind==7:
            op=r.choice(['lb','lbu','lh','lhu','lw','sb','sh','sw']); align=4 if op in ('lw','sw') else 2 if op in ('lh','lhu','sh') else 1
            p.append((op,rd,0,r.randrange(0,256//align)*align))
        elif kind==8:
            label=f'skip_{i}'; p.extend([(r.choice(['beq','bne','blt','bge','bltu','bgeu']),a,b,label),('addi',rd,a,17),label])
        else: p.append((r.choice(['lui','auipc']),rd,r.randrange(1<<20)))
    return p+[('ebreak',)]
