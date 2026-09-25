import Base

# Safe exclusive scan oracle; native sequential loop. Source preserved.
type State is Type:
  State{source: Array<U32>, offsets: Array<U32>, total: U32}

def put(i: U32, +total: U32, offsets: Array<U32>, r: Array<U32> & U32) -> State:
  (a,x) = r
  State{a,Array.set(U32,offsets,i,total),(total + x : U32)}

def loop(n: Nat, +i: U32, s: State) -> State:
  match n:
    case 0n: s
    case 1n+p:
      State{a,b,total} = s
      loop(p,(i + 1 : U32),put(i,total,b,Array.get(U32,a,i)))

def exclusive(n: U32, a: Array<U32>, offsets: Array<U32>) -> State:
  loop(U32.to_nat(n),0,State{a,offsets,0})
