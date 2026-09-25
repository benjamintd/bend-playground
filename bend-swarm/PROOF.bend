import Base
import ./LAWS.bend as Laws
import ./engine/parallel/partition.bend as P

def Laws.swap_involution(T,buffers):
  match buffers:
    case (a,b): {==}

def Laws.partition_reassembly(T,a,b):
  {==}

def Laws.capacity_doubles(d):
  {==}

law positive_step:
  for -n: Nat
  for r: (&p: Nat -> {n == 1n+p : Nat})
  exs q: Nat
  {Nat.add(n,n) == 1n+q : Nat}

def positive_step(n,r):
  (+p,e) = r
  %Equal.sym(Nat,n,1n+p,e) : (&q: Nat -> {Nat.add(_,_) == 1n+q : Nat})
  (Nat.add(p,1n+p),{==})

def Laws.capacity_positive(d):
  match d:
    case 0n: (0n,{==})
    case 1n+p: positive_step(P.capacity(p),Laws.capacity_positive(p))
