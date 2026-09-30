import Base
import ../engine/camera.bend as C
import ../engine/spatial/layout.bend as L
import ../engine/render/project.bend as P
import ../engine/render/batch.bend as B
import ../engine/render/mesh.bend as M
import ../engine/render/scene.bend as S
import ../engine/profile/frame.bend as Profile
import ../engine/parallel/policy.bend as Policy

def geometry(visible: Bool, prepared: Maybe<&2, C.View>, batch: B.Batch) -> B.Batch:
  match visible prepared:
    case True{} Some{view}:
      P.triangle(view,P.Triangle{P.Vertex{L.Point{F32.neg(0.5),0.5,0.0},1.0},
        P.Vertex{L.Point{0.5,0.5,0.0},1.0},P.Vertex{L.Point{F32.neg(0.5),F32.neg(0.5),0.0},1.0},16777215},B.clear(batch))
    case _ _: B.clear(batch)
def scene(+level: U32, visible: Bool, batch: B.Batch) -> B.Batch:
  +size = U32.to_f32(S.width(level))
  geometry(visible,C.prepare(C.orthographic(2.0,0.1,10.0),C.viewport(640.0,640.0,size,size)),batch)
def scan(n: Nat, +i: U32, ink: U32, invalid: U32, r: Array<U32> & U32) -> Array<U32> & U32 & U32:
  match n:
    case 0n:
      (pixels,_) = r
      (pixels,ink,invalid)
    case 1n+k:
      (pixels,+color) = r
      scan(k,(i + 1 : U32),(ink + Bool.to_u32(U32.is_eq(color,16777215)) : U32),
        (invalid + Bool.to_u32(U32.is_ne(color,16777215) && U32.is_ne(color,66051)) : U32),Array.get(U32,pixels,(i + 1 : U32)))
def report_scanned(index: M.Index, fragments: Array<M.Fragment>, +level: U32, background: U32,
  batch: B.Batch, image: Image, +profile: Profile.Sample, count: U32, r: Array<U32> & U32 & U32) -> IO(S.Frame):
  Profile.Sample{Policy.Policy{_,_,_,gpu,_,_},sim,geo,_,_,_} = profile
  (pixels,ink,invalid) = r
  do IO<S.Frame>:
    Unit <- IO.print(U32.show(level) ++ "," ++ U32.show(count) ++ "," ++ U32.show(ink) ++ "," ++ U32.show(invalid)
      ++ "," ++ U32.show(Bool.to_u32(gpu)) ++ "," ++ U32.show(sim) ++ "," ++ U32.show(geo))
    return S.Frame{S.Target{index,pixels,fragments,level,background},batch,image,profile}
def report_sized(index: M.Index, fragments: Array<M.Fragment>, level: U32, background: U32,
  batch: B.Batch, image: Image, profile: Profile.Sample, r: Array<U32> & U32) -> IO(S.Frame):
  (pixels,+count) = r
  report_scanned(index,fragments,level,background,batch,image,profile,count,
    scan(U32.to_nat(count),0,0,0,Array.get(U32,pixels,0)))
def report(frame: S.Frame) -> IO(S.Frame):
  S.Frame{S.Target{index,pixels,fragments,level,background},batch,image,profile} = frame
  report_sized(index,fragments,level,background,batch,image,profile,Array.size(U32,pixels))
def frames(xs: List<(U32 & Bool)>, frame: S.Frame) -> IO(Unit):
  match xs:
    case Nil{}: IO.pure(Unit,Unit{})
    case (+level,visible) <> rest:
      S.Frame{target,batch,image,_} = frame
      do IO<Unit>:
        drawn : S.Frame <- S.draw(True{},17,23,scene(level,visible,batch),S.resize(level,target),image)
        checked : S.Frame <- report(drawn)
        frames(rest,checked)
def main() -> IO(Unit):
  frames([(0,True{}),(0,False{}),(1,True{}),(1,False{}),(2,True{}),(0,False{})],
    S.Frame{S.create(0,66051),B.create(1024),Pix{66051},Profile.empty()})
