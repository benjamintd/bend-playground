import Base
import ./tiles.bend as Tiles
import ./image.bend as ImageBuffer
import ../spatial.bend as Spatial
import ../spatial/internal/index.bend as Index
import ../spatial/layout.bend as L
import ../core/math.bend as Math
import ./mesh.bend as M

# Generic additive sprites over a periodic 1024² world. A radius <= 7 world
# units fits nine neighboring 8-unit cells. Each tile owns 8x8 output pixels
# at scale 0 (1024²), or 16x16 at scale 1 (2048²).
# Source positions must match the centers returned by the sprite callback.
type Splat is Data:
  Splat{x: F32, y: F32, color: U32}
type Settings is Data:
  Settings{smooth: Bool, radius: F32, gain: F32}
def space() -> L.Layout:
  L.Layout{2,7n,7n,0n,8.0,0.0,0.0,0.0,True{}}
type Buffers<-S: Type> is Type:
  Buffers{source: S, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>, settings: Settings}
def channel_sum(+a: U32, +b: U32, +shift: Nat) -> U32:
  U32.min(255,(U32.and(U32.shrn(a,shift),255) + U32.and(U32.shrn(b,shift),255) : U32))
def add(+a: U32, +b: U32) -> U32:
  (channel_sum(a,b,16n) * 65536 + channel_sum(a,b,8n) * 256 + channel_sum(a,b,0n) : U32)
def intensity(~scale: Nat,s: Settings, +distance2: F32) -> F32:
  Settings{smooth,+radius,gain} = s
  +r = (F32.min(7.0,F32.max(0.5,radius)) * U32.to_f32(U32.shln(1,scale)) : F32)
  +coverage = L.pick(smooth,F32.min(1.0,F32.max(0.0,(r + 0.5 - F32.sqrt(distance2) : F32))),L.pick((distance2 < r * r : F32),1.0,0.0))
  +core = F32.max(0.0,(1.0 - distance2 / (r * r) : F32))
  (coverage * gain * (0.1 + core * core * 0.9) : F32)
def blended(i: U32, color: U32, r: Array<U32> & U32) -> Array<U32>:
  (p,old) = r
  Array.set(U32,p,i,add(old,color))
def plot(on: Bool, +i: U32, color: U32, light: F32, p: Array<U32>) -> Array<U32>:
  match on:
    case False{}: p
    case True{}: blended(i,M.shaded(color,light),Array.get(U32,p,i))
def pixels(~scale: Nat,n: Nat, +i: U32, +x: U32, +y: U32, +width: U32, +cx: F32, +cy: F32, +color: U32, +settings: Settings, p: Array<U32>) -> Array<U32>:
  match n:
    case 0n: p
    case 1n+k:
      +px = (x + i % width : U32)
      +py = (y + i / width : U32)
      +dx = (U32.to_f32(px) + 0.5 - cx : F32)
      +dy = (U32.to_f32(py) + 0.5 - cy : F32)
      +light = intensity(~scale,settings,(dx * dx + dy * dy : F32))
      pixels(~scale,k,(i + 1 : U32),x,y,width,cx,cy,color,settings,plot((light > 0.001 : F32),(px + py * U32.shln(1024,scale) : U32),color,light,p))
def periodic_delta(+x: F32) -> F32:
  (x - F32.floor((x / 1024.0 + 0.5 : F32)) * 1024.0 : F32)
def bounds(~scale: Nat,+x: U32, +y: U32, +cx: F32, +cy: F32, color: U32, +settings: Settings, p: Array<U32>) -> Array<U32>:
  Settings{_,radius,_} = settings
  +r = (F32.min(7.0,F32.max(0.5,radius)) * U32.to_f32(U32.shln(1,scale)) : F32)
  +left = F32.to_u32(F32.max(U32.to_f32(x),F32.floor((cx - r : F32))))
  +top = F32.to_u32(F32.max(U32.to_f32(y),F32.floor((cy - r : F32))))
  +right = F32.to_u32(F32.max(U32.to_f32(left),F32.min(U32.to_f32((x + U32.shln(8,scale) : U32)),F32.ceil((cx + r + 1.0 : F32)))))
  +bottom = F32.to_u32(F32.max(U32.to_f32(top),F32.min(U32.to_f32((y + U32.shln(8,scale) : U32)),F32.ceil((cy + r + 1.0 : F32)))))
  +width = (right - left : U32)
  pixels(~scale,U32.to_nat((width * (bottom - top) : U32)),0,left,top,U32.max(width,1),cx,cy,color,settings,p)
def sampled(~scale: Nat, ~S: Type, +x: U32, +y: U32, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>, +settings: Settings, r: S & Splat) -> Buffers<S>:
  (s,Splat{cx,cy,color}) = r
  +factor = U32.to_f32(U32.shln(1,scale))
  +wx = (U32.to_f32(x) / factor + 4.0 : F32)
  +wy = (U32.to_f32(y) / factor + 4.0 : F32)
  Buffers{s,offsets,ids,bounds(~scale,x,y,((wx + periodic_delta((cx - wx : F32))) * factor : F32),
    ((wy + periodic_delta((cy - wy : F32))) * factor : F32),color,settings,pixels),settings}

def identified(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, x: U32, y: U32, s: S, offsets: Array<U32>, pixels: Array<U32>, settings: Settings, r: Array<U32> & U32) -> Buffers<S>:
  (ids,id) = r
  sampled(~scale,~S,x,y,offsets,ids,pixels,settings,read(id,s))
def points(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, n: Nat, +i: U32, +x: U32, +y: U32, b: Buffers<S>) -> Buffers<S>:
  match n:
    case 0n: b
    case 1n+k:
      Buffers{s,offsets,ids,pixels,settings} = b
      points(~scale,~S,~read,k,(i + 1 : U32),x,y,identified(~scale,~S,~read,x,y,s,offsets,pixels,settings,Array.get(U32,ids,i)))
def range_end(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, x: U32, y: U32, +start: U32, s: S, ids: Array<U32>, pixels: Array<U32>, settings: Settings, r: Array<U32> & U32) -> Buffers<S>:
  (offsets,end) = r
  points(~scale,~S,~read,U32.to_nat((end - start : U32)),start,x,y,Buffers{s,offsets,ids,pixels,settings})
def range_start(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, x: U32, y: U32, cell: U32, s: S, ids: Array<U32>, pixels: Array<U32>, settings: Settings, r: Array<U32> & U32) -> Buffers<S>:
  (offsets,start) = r
  range_end(~scale,~S,~read,x,y,start,s,ids,pixels,settings,Array.get(U32,offsets,(cell + 1 : U32)))
def cells(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, +n: Nat, +x: U32, +y: U32, b: Buffers<S>) -> Buffers<S>:
  match n:
    case 0n: b
    case 1n+k:
      Buffers{s,offsets,ids,pixels,settings} = b
      +j = U32.from_nat(k)
      +cell = (U32.and((U32.shrn(x,Nat.add(3n,scale)) + j % 3 - 1 : U32),127)
        + U32.and((U32.shrn(y,Nat.add(3n,scale)) + j / 3 - 1 : U32),127) * 128 : U32)
      cells(~scale,~S,~read,k,x,y,range_start(~scale,~S,~read,x,y,cell,s,ids,pixels,settings,Array.get(U32,offsets,cell)))
def clear(~scale: Nat,+n: Nat, +x: U32, +y: U32, p: Array<U32>) -> Array<U32>:
  match n:
    case 0n: p
    case 1n+k:
      +i = U32.from_nat(k)
      clear(~scale,k,x,y,Array.set(U32,p,(x + i % U32.shln(8,scale) + (y + i / U32.shln(8,scale)) * U32.shln(1024,scale) : U32),263692))
def image_done(~S: Type, s: S, offsets: Array<U32>, ids: Array<U32>, settings: Settings, r: Array<U32> & Image) -> Buffers<S> & Image:
  (pixels,image) = r
  (Buffers{s,offsets,ids,pixels,settings},image)
def tile_done(~scale: Nat,~S: Type, x: U32, y: U32, b: Buffers<S>) -> Buffers<S> & Image:
  Buffers{s,offsets,ids,pixels,settings} = b
  image_done(~S,s,offsets,ids,settings,ImageBuffer.leaf(~Nat.add(1n,scale),True{},x,y,pixels))
def tile(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, +x: U32, +y: U32, b: Buffers<S>, old: Image) -> Buffers<S> & Image:
  Buffers{s,offsets,ids,pixels,settings} = b
  tile_done(~scale,~S,x,y,cells(~scale,~S,~read,9n,x,y,Buffers{s,offsets,ids,clear(~scale,U32.to_nat(U32.shln(64,Nat.add(scale,scale))),x,y,pixels),settings}))
def join(~S: Type, ~merge: S -> S -> S, a: Buffers<S>, b: Buffers<S>) -> Buffers<S>:
  Buffers{as,ao,ai,ap,c} = a
  Buffers{bs,bo,bi,bp,_} = b
  Buffers{merge(as,bs),Array.join(U32,ao,bo),Array.join(U32,ai,bi),Array.join(U32,ap,bp),c}
def leaf(~scale: Nat, ~S: Type, ~read: @+i:U32 -> S -> S & Splat, x: U32, y: U32, b: Buffers<S>, old: Image) -> Buffers<S> & Image:
  tile(~scale,~S,~read,x,y,b,old)
def render(~scale: Nat, ~S: Type, ~read: @+i:U32 -> S -> S & Splat, ~merge: S -> S -> S, gpu: Bool, b: Buffers<S>, old: Image) -> Buffers<S> & Image:
  match gpu:
    case True{}: Tiles.tree!(~Buffers<S>,~U32.shln(8,scale),~leaf(~scale,~S,~read),~join(~S,~merge),7n,0,0,b,Tiles.open(old))
    case False{}: Tiles.tree(~Buffers<S>,~U32.shln(8,scale),~leaf(~scale,~S,~read),~join(~S,~merge),7n,0,0,b,Tiles.open(old))
def finished(~S: Type, cap: U32, counts: Array<U32>, cursors: Array<U32>, r: Buffers<S> & Image) -> S & Spatial.Index(space()) & Array<U32> & Image:
  (Buffers{s,offsets,ids,pixels,_},image) = r
  (s,Index.Index{cap,counts,offsets,cursors,ids},pixels,image)
def draw_level(~scale: Nat,~S: Type, ~read: @+i:U32 -> S -> S & Splat, ~merge: S -> S -> S, gpu: Bool, settings: Settings,
  snapshot: Spatial.Snapshot(space(),S), pixels: Array<U32>, old: Image) -> S & Spatial.Index(space()) & Array<U32> & Image:
  Index.Snapshot{_,s,Index.Index{cap,counts,offsets,cursors,ids}} = snapshot
  finished(~S,cap,counts,cursors,render(~scale,~S,~read,~merge,gpu,Buffers{s,offsets,ids,pixels,settings},old))

def draw(~S: Type, ~read: @+i:U32 -> S -> S & Splat, ~merge: S -> S -> S, gpu: Bool, settings: Settings,
  snapshot: Spatial.Snapshot(space(),S), pixels: Array<U32>, old: Image) -> S & Spatial.Index(space()) & Array<U32> & Image:
  draw_level(~0n,~S,~read,~merge,gpu,settings,snapshot,pixels,old)
