import Base
import ./mesh.bend as M

# Supported interface: create, clear, push; Batch owns its triangle storage.
# Append grows before a full array can wrap. Clear reuses the allocated buffer.
type Batch is Type:
  Batch{triangles: Array<M.Triangle>, count: U32, capacity: U32}
def allocated(+depth: Nat) -> Batch:
  Batch{Array.new(M.Triangle,depth,M.blank()),0,U32.shln(1,depth)}
# Round the requested initial capacity up to a power of two (minimum one).
# Bound the exponent to 30 so the allocation size remains representable in U32.
def create(capacity: U32) -> Batch:
  allocated(U32.log2((U32.clamp(capacity,1,1073741824) * 2 - 1 : U32)))
def clear(b: Batch) -> Batch:
  Batch{tris,_,cap} = b
  Batch{tris,0,cap}
def copy_read(n: Nat, +i: U32, out: Array<M.Triangle>, r: Array<M.Triangle> & M.Triangle) -> Array<M.Triangle>:
  match n:
    case 0n: out
    case 1n+k:
      (old,t) = r
      copy_read(k,(i + 1 : U32),Array.set(M.Triangle,out,i,t),Array.get(M.Triangle,old,(i + 1 : U32)))
def copy(n: Nat, +i: U32, old: Array<M.Triangle>, out: Array<M.Triangle>) -> Array<M.Triangle>:
  copy_read(n,i,out,Array.get(M.Triangle,old,i))
def push_ready(grow: Bool, t: M.Triangle, b: Batch) -> Batch:
  match grow:
    case False{}:
      Batch{tris,+n,cap} = b
      Batch{Array.set(M.Triangle,tris,n,t),(n + 1 : U32),cap}
    case True{}:
      Batch{tris,+n,+cap} = b
      Batch{Array.set(M.Triangle,copy(U32.to_nat(n),0,tris,Array.new(M.Triangle,Nat.add(U32.log2(cap),1n),M.blank())),n,t),(n + 1 : U32),(cap * 2 : U32)}
def push(t: M.Triangle, b: Batch) -> Batch:
  Batch{tris,+n,+cap} = b
  push_ready(U32.is_eq(n,cap),t,Batch{tris,n,cap})
