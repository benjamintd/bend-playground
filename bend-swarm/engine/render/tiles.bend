import Base

# Image children are owned separately from the aliased render state. Unlike a
# previous frame, a resolve pass reads these children as its source image.
type Four is Type:
  Four{a: Image, b: Image, c: Image, d: Image}
def open(image: Image) -> Four:
  match image:
    case Pix{+c}: Four{Pix{c},Pix{c},Pix{c},Pix{c}}
    case Qua{a,b,c,d}: Four{a,b,c,d}
def joined(~S: Type, ~merge: S -> S -> S, a: S & Image, b: S & Image, c: S & Image, d: S & Image) -> S & Image:
  (as,ai) = a
  (bs,bi) = b
  (cs,ci) = c
  (ds,di) = d
  (merge(merge(as,bs),merge(cs,ds)),Qua{ai,bi,ci,di})

# INTERNAL unsafe seam. A leaf owns its [x,x+size) × [y,y+size) rectangle.
# Shared state is read-only except for these disjoint writes; merge must rejoin
# only aliases of the same allocations. No handle escapes the completed tree.
# Each image subtree reaches exactly one leaf, which must consume it. Templates
# keep leaf/merge/size out of runtime state and preserve specialized GPU roots.
# Keep the CPU/GPU branch and bang in each renderer; a shared dispatch wrapper
# failed native device dispatch on the pinned Bend. See repros/tiles-indirect-dispatch.md.
@unsafe
def tree(~S: Type, ~size: U32, ~leaf: U32 -> U32 -> S -> Image -> S & Image, ~merge: S -> S -> S,
  +depth: Nat, +x: U32, +y: U32, +state: S, image: Four) -> S & Image:
  match depth:
    case 0n:
      Four{a,b,c,d} = image
      leaf(x,y,state,Qua{a,b,c,d})
    case 1n+k:
      Four{a,b,c,d} = image
      +h = U32.shln(size,k)
      ra rb rc rd = tree(~S,~size,~leaf,~merge,k,x,y,state,open(a)) tree(~S,~size,~leaf,~merge,k,(x + h : U32),y,state,open(b))
        tree(~S,~size,~leaf,~merge,k,x,(y + h : U32),state,open(c)) tree(~S,~size,~leaf,~merge,k,(x + h : U32),(y + h : U32),state,open(d))
      joined(~S,~merge,ra,rb,rc,rd)
