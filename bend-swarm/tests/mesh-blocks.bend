import Base
import ../engine/render/mesh.bend as M

# Every background pixel has a different color and spatially varying depth.
# This detects swapped block corners and cross-row reads/writes.
def background(x: U32, y: U32) -> M.Fragment:
  +px = x
  +py = y
  M.Fragment{(1.0 + U32.to_f32(px) / 256.0 + U32.to_f32(py) / 512.0 : F32),(px * 257 + py : U32)}
def built(r: Array<M.Triangle> & M.Index) -> M.Drawing & Image:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  M.render(False{},M.Drawing{tris,offsets,ids,Array.new(U32,18n,0),
    M.backdrop(~False{},~background,Array.new(M.Fragment,19n,M.Fragment{0.0,0}))},Pix{0})
def render(n: U32, tris: Array<M.Triangle>) -> M.Drawing & Image:
  built(M.build(False{},n,tris,M.empty()))
