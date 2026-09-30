import Base
import ./play.bend as P
import ./view.bend as V
import ../../engine/render/mesh.bend as M
import ../../engine/render/batch.bend as B
import ./text-coverage.bend as TextCoverage

type Renderer is Type:
  Renderer{batch: B.Batch, index: M.Index, pixels: Array<U32>, fragments: Array<M.Fragment>}
def create() -> Renderer:
  Renderer{B.create(32768),M.empty(),Array.new(U32,20n,0),
    M.backdrop_level(~1n,~V.background,Array.new(M.Fragment,21n,M.Fragment{0.0,0}))}
def finished(n: U32, capacity: U32, counts: Array<U32>, cursors: Array<U32>, cap: U32, r: M.Drawing & Image) -> Renderer & Image:
  (M.Drawing{tris,offsets,ids,pixels,fragments},image) = r
  (Renderer{B.Batch{tris,n,capacity},M.Index{counts,offsets,cursors,ids,cap},pixels,fragments},image)
# Full 1024-square output. Four-sample coverage is restricted to text tiles,
# preserving rounded lettering without multisampling the whole world.
def binned(gpu: Bool, n: U32, capacity: U32, pixels: Array<U32>, fragments: Array<M.Fragment>, old: Image,
  r: Array<M.Triangle> & M.Index) -> Renderer & Image:
  (tris,M.Index{counts,offsets,cursors,ids,cap}) = r
  finished(n,capacity,counts,cursors,cap,TextCoverage.draw(gpu,
    M.Drawing{tris,offsets,ids,pixels,fragments},old))
def projected(+gpu: Bool, index: M.Index, pixels: Array<U32>, fragments: Array<M.Fragment>, old: Image, scene: B.Batch) -> Renderer & Image:
  B.Batch{tris,+n,capacity} = scene
  binned(gpu,n,capacity,pixels,fragments,old,M.build_level(~1n,gpu,n,tris,index))
def frame(gpu: Bool, p: P.Play, renderer: Renderer, old: Image) -> Renderer & Image:
  Renderer{batch,index,pixels,fragments} = renderer
  projected(gpu,index,pixels,fragments,old,V.scene(p,batch))
