"""Small deterministic microbenchmarks; no commercial CPU comparisons."""
def benchmark_programs():
 return {
  'bench_dependent_alu': [('addi',1,0,1)]+[('addi',1,1,3) for _ in range(200)]+[('ebreak',)],
  'bench_independent_alu': [('lw',1,0,0)]+[('addi',i%28+2,0,i) for i in range(200)]+[('ebreak',)],
  'bench_branch_loop': [('addi',1,0,100),'loop',('addi',1,1,-1),('bne',1,0,'loop'),('ebreak',)],
  'bench_cache_locality': [('addi',1,0,100),'loop',('lw',2,0,0),('addi',3,2,1),('addi',1,1,-1),('bne',1,0,'loop'),('ebreak',)],
  'bench_cache_conflict': [('addi',1,0,60),'loop',('lw',2,0,0),('lw',3,0,64),('addi',1,1,-1),('bne',1,0,'loop'),('ebreak',)],
  'bench_memory_hazards': [('addi',1,0,100),'loop',('sw',1,0,0),('lb',2,0,0),('sb',2,0,1),('lh',3,0,0),('addi',1,1,-1),('bne',1,0,'loop'),('ebreak',)],
  'bench_multiply_overlap': [('addi',1,0,77),('addi',2,0,3)]+sum(([('div',3,1,2)]+[('addi',j+4,0,j) for j in range(12)] for _ in range(20)),[])+[('ebreak',)],
 }
