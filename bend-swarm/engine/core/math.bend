import Base

def pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}: a
    case False{}: b

def word(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}: a
    case False{}: b

def wrap(+x: F32) -> F32:
  (x - F32.floor((x / 1024.0 : F32)) * 1024.0 : F32)

def hash(+x: U32) -> U32:
  +a = U32.xor(x, U32.shrn(x, 16n))
  +b = (a * 2146121005 : U32)
  +c = U32.xor(b, U32.shrn(b, 15n))
  +d = (c * 2221713035 : U32)
  U32.xor(d, U32.shrn(d, 16n))

def random(i: U32, seed: U32) -> F32:
  (U32.to_f32(U32.and(hash((i + seed : U32)), 16777215)) / 16777216.0 : F32)
