import Base
import ./regions.bend as Region

type State is Type:
  State{array: Array<U32>, total: U32}

def add(total: U32, r: Array<U32> & U32) -> State:
  (a,x) = r
  State{a,(total + x : U32)}

def loop(n: Nat, +i: U32, s: State) -> State:
  match n:
    case 0n: s
    case 1n+p:
      State{a,total} = s
      loop(p,(i + 1 : U32),add(total,Array.get(U32,a,i)))

def leaf(start: U32, n: U32, s: State) -> State:
  State{a,_} = s
  loop(U32.to_nat(n),start,State{a,0})

def join(a: State, b: State) -> State:
  State{aa,at} = a
  State{ba,bt} = b
  State{Array.join(U32,aa,ba),(at + bt : U32)}

def sum(depth: Nat, +n: U32, a: Array<U32>) -> State:
  Region.run(~State,~leaf,~join,Nat.min(depth,U32.log2(n)),0,n,State{a,0})
