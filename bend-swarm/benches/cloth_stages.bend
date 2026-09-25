import Base
import ../demos/cloth/frame.bend as F
import ../demos/cloth/simulation.bend as S
import ../demos/cloth/physics.bend as P
import ../demos/cloth/view.bend as V
import ../demos/cloth/world.bend as W
import ../demos/cloth/surface.bend as Surface
import ../engine/spatial.bend as Spatial
import ../engine/render/mesh.bend as M
import ../engine/core/time.bend as Time

def raster(report: Bool, sim: U32, projection: U32, binning: U32, start: Nat, state: S.State,
  pixels: Array<U32>, background: Array<M.Fragment>, image: Image, r: Array<M.Triangle> & M.Index) -> IO(F.Frame):
  (tris,M.Index{counts,offsets,cursors,ids,cap}) = r
  do IO<F.Frame>:
    drawn : M.Drawing & Image = F.render(True{},False{},M.Drawing{tris,offsets,ids,pixels,background},image)
    end : Nat <- Time.micros()
    Unit <- Bool.pick(IO(Unit),report,IO.print(U32.show(sim) ++ "," ++ U32.show(projection) ++ "," ++ U32.show(binning) ++ "," ++ U32.show(Time.elapsed(start,end))),IO.pure(Unit,Unit{}))
    return F.drawn(state,counts,cursors,cap,0,0,drawn)
def binned(report: Bool, sim: U32, projection: U32, start: Nat, state: S.State,
  pixels: Array<U32>, background: Array<M.Fragment>, image: Image, r: Array<M.Triangle> & M.Index) -> IO(F.Frame):
  do IO<F.Frame>:
    +end : Nat <- Time.micros()
    raster(report,sim,projection,Time.elapsed(start,end),end,state,pixels,background,image,r)
def projected(report: Bool, sim: U32, start: Nat, previous: W.Positions, scratch: W.Positions, spatial: Spatial.Index(P.space()),
  samples: Array<Surface.Sample>, checks: Nat, neighbors: Nat, index: M.Index, pixels: Array<U32>, background: Array<M.Fragment>, image: Image, r: V.Projection) -> IO(F.Frame):
  V.Projection{current,tris,side,_} = r
  do IO<F.Frame>:
    +end : Nat <- Time.micros()
    binned(report,sim,Time.elapsed(start,end),end,S.State{side,current,previous,scratch,spatial,samples,checks,neighbors},pixels,background,image,
      M.build_quality(True{},False{},7938,tris,index))
def project(report: Bool, start: Nat, tris: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, background: Array<M.Fragment>, image: Image, s: S.State) -> IO(F.Frame):
  S.State{+side,current,previous,scratch,spatial,samples,checks,neighbors} = s
  do IO<F.Frame>:
    +end : Nat <- Time.micros()
    projected(report,Time.elapsed(start,end),end,previous,scratch,spatial,samples,checks,neighbors,index,pixels,background,image,
      V.triangles_run(False{},7938,V.Projection{current,tris,side,True{}}))
def frame(tick: U32, report: Bool, f: F.Frame) -> IO(F.Frame):
  F.Frame{state,tris,index,pixels,background,image,_,_} = f
  do IO<F.Frame>:
    start : Nat <- Time.micros()
    state : S.State <- F.advance(False{},False{},0n,2n,P.Controls{32,4294967295,0.0,0.0,0.0,(U32.to_f32(tick) / 60.0 : F32),1.5},state)
    project(report,start,tris,index,pixels,background,image,state)
def frames(n: Nat, +tick: U32, f: F.Frame) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        f : F.Frame <- frame(tick,(tick >= 120 : U32),f)
        frames(k,(tick + 1 : U32),f)
def main() -> IO(Unit):
  do IO<Unit>:
    f : F.Frame <- F.create(6n)
    Unit <- IO.print("simulation_us,projection_us,binning_us,raster_us")
    frames(720n,0,f)
