import Base
import ./regions.bend as Region

def put(~T: Data, ~f: T -> T, i: U32, r: Array<T> & T) -> Array<T>:
  (a, x) = r
  Array.set(T, a, i, f(x))

def loop(~T: Data, ~f: T -> T, n: Nat, +i: U32, a: Array<T>) -> Array<T>:
  match n:
    case 0n: a
    case 1n+p:
      loop(~T, ~f, p, (i + 1 : U32), put(~T, ~f, i, Array.get(T, a, i)))

def leaf(~T: Data, ~f: T -> T, start: U32, n: U32, a: Array<T>) -> Array<T>:
  loop(~T, ~f, U32.to_nat(n), start, a)

def sized(~T: Data, ~f: T -> T, depth: Nat, r: Array<T> & U32) -> Array<T>:
  (a, +n) = r
  Region.run(~Array<T>, ~leaf(~T, ~f), ~Array.join(T),
    Nat.min(depth, U32.log2(n)), 0, n, a)

def run(~T: Data, ~f: T -> T, depth: Nat, a: Array<T>) -> Array<T>:
  sized(~T, ~f, depth, Array.size(T, a))
