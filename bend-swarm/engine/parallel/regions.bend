import Base

# INTERNAL unsafe boundary. Caller supplies a join that rejoins ONLY aliases
# of the same storage. Leaves own [start,start+n); all other arrays are read
# only, or writes use atomics. No handle escapes the completed fork tree.
# Handles odd active counts: right length is n - floor(n/2).
# Callers clamp depth to floor(log2(count)); capacity remains power-of-two.
@unsafe
def run(~S: Type, ~leaf: U32 -> U32 -> S -> S, ~join: S -> S -> S,
  +depth: Nat, +start: U32, +n: U32, +state: S) -> S:
  match depth:
    case 0n:
      leaf(start, n, state)
    case 1n+d:
      +half = U32.shr(n)
      l r = run(~S, ~leaf, ~join, d, start, half, state)
        run(~S, ~leaf, ~join, d, (start + half : U32), (n - half : U32), state)
      join(l, r)
