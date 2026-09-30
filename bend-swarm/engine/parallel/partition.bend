import Base

def capacity(d: Nat) -> Nat:
  match d:
    case 0n: 1n
    case 1n+p:
      +half = capacity(p)
      Nat.add(half,half)

def merge(-T: Type, r: Array<T> & Array<T>) -> Array<T>:
  (a,b) = r
  ANode{a,b}

def split_node(-T: Type, a: Array<T>, b: Array<T>) -> Array<T> & Array<T>:
  (a,b)

def swap(-T: Type, r: T & T) -> T & T:
  (a,b) = r
  (b,a)
