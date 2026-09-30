import Base
import ./mesh.bend as M
import ./downsample.bend as Resolve
import ../parallel/regions.bend as Region

type Query is Type:
  Query{triangles: Array<M.Triangle>, ids: Array<U32>, a: M.Fragment, b: M.Fragment, c: M.Fragment, d: M.Fragment}
def sampled(+x: F32, +y: F32, ids: Array<U32>, a: M.Fragment, b: M.Fragment, c: M.Fragment, d: M.Fragment, r: Array<M.Triangle> & M.Triangle) -> Query:
  (tris,+t) = r
  # Rotated four-sample grid: four distinct horizontal and vertical positions.
  Query{tris,ids,M.sample((x - 0.125 : F32),(y - 0.375 : F32),t,a),M.sample((x + 0.375 : F32),(y - 0.125 : F32),t,b),
    M.sample((x - 0.375 : F32),(y + 0.125 : F32),t,c),M.sample((x + 0.125 : F32),(y + 0.375 : F32),t,d)}
def identified(x: F32, y: F32, tris: Array<M.Triangle>, a: M.Fragment, b: M.Fragment, c: M.Fragment, d: M.Fragment, r: Array<U32> & U32) -> Query:
  (ids,id) = r
  sampled(x,y,ids,a,b,c,d,Array.get(M.Triangle,tris,id))
def candidates(n: Nat, +i: U32, +x: F32, +y: F32, q: Query) -> Query:
  match n:
    case 0n: q
    case 1n+k:
      Query{tris,ids,a,b,c,d} = q
      candidates(k,(i + 1 : U32),x,y,identified(x,y,tris,a,b,c,d,Array.get(U32,ids,i)))
def resolved(q: Query) -> M.Query:
  Query{tris,ids,M.Fragment{az,ac},M.Fragment{bz,bc},M.Fragment{cz,cc},M.Fragment{dz,dc}} = q
  M.Query{tris,ids,M.Fragment{F32.min(F32.min(az,bz),F32.min(cz,dz)),Resolve.average(ac,bc,cc,dc)}}
def query(count: U32, start: U32, x: F32, y: F32, tris: Array<M.Triangle>, ids: Array<U32>, +background: M.Fragment) -> M.Query:
  match count:
    case 0: M.Query{tris,ids,background}
    case _:
      resolved(candidates(U32.to_nat(count),start,x,y,Query{tris,ids,background,background,background,background}))
def background(~level: Nat, i: U32, x: F32, y: F32, start: U32, count: U32, tris: Array<M.Triangle>, ids: Array<U32>, offsets: Array<U32>, pixels: Array<U32>, r: Array<M.Fragment> & M.Fragment) -> M.Drawing:
  (fragments,bg) = r
  M.written(~level,i,offsets,pixels,fragments,query(count,start,x,y,tris,ids,bg))
def pixel_loop(~level: Nat, +n: Nat, +x: U32, +y: U32, +start: U32, +count: U32, b: M.Drawing) -> M.Drawing:
  match n:
    case 0n: b
    case 1n+k:
      M.Drawing{tris,offsets,ids,p,fragments} = b
      +j = U32.from_nat(k)
      +px = (x + U32.and(j,(U32.shln(4,level) - 1 : U32)) : U32)
      +py = (y + U32.shrn(j,Nat.add(level,2n)) : U32)
      +i = (px + py * U32.shln(512,level) : U32)
      pixel_loop(~level,k,x,y,start,count,background(~level,i,(U32.to_f32(px) + 0.5 : F32),(U32.to_f32(py) + 0.5 : F32),
        start,count,tris,ids,offsets,p,Array.get(M.Fragment,fragments,i)))
def end(~level: Nat, x: U32, y: U32, +start: U32, tris: Array<M.Triangle>, ids: Array<U32>, pixels: Array<U32>, fragments: Array<M.Fragment>, r: Array<U32> & U32) -> M.Drawing:
  (offsets,last) = r
  pixel_loop(~level,U32.to_nat(U32.shln(16,Nat.add(level,level))),x,y,start,(last - start : U32),M.Drawing{tris,offsets,ids,pixels,fragments})
def start(~level: Nat, +cell: U32, tris: Array<M.Triangle>, ids: Array<U32>, pixels: Array<U32>, fragments: Array<M.Fragment>, r: Array<U32> & U32) -> M.Drawing:
  (offsets,first) = r
  end(~level,((cell % 128) * U32.shln(4,level) : U32),((cell / 128) * U32.shln(4,level) : U32),first,tris,ids,pixels,fragments,Array.get(U32,offsets,(cell + 1 : U32)))
def loop(~level: Nat, n: Nat, +cell: U32, b: M.Drawing) -> M.Drawing:
  match n:
    case 0n: b
    case 1n+k:
      M.Drawing{tris,offsets,ids,pixels,fragments} = b
      loop(~level,k,(cell + 1 : U32),start(~level,cell,tris,ids,pixels,fragments,Array.get(U32,offsets,cell)))
def leaf(~level: Nat, start: U32, count: U32, b: M.Drawing) -> M.Drawing:
  loop(~level,U32.to_nat(count),start,b)
def root(~level: Nat, depth: Nat, b: M.Drawing) -> M.Drawing:
  Region.run(~M.Drawing,~leaf(~level),~M.join,depth,0,16384,b)
def render(~level: Nat, gpu: Bool, b: M.Drawing) -> M.Drawing:
  match gpu:
    case True{}: root!(~level,14n,b)
    case False{}: root(~level,8n,b)
