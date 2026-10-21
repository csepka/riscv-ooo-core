.option norvc
.option norelax
.text
.global _start
_start:
    addi x1,x0,0
    addi x2,x0,1
    addi x3,x0,12
loop:
    add x4,x1,x2
    addi x1,x2,0
    addi x2,x4,0
    addi x3,x3,-1
    bne x3,x0,loop
    sw x1,0(x0)
    ebreak
