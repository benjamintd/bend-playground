import Base
import ../../demos/cloth/simulation.bend as S
import ../../demos/cloth/physics.bend as P
import ../../demos/cloth/surface.bend as Surface
import ../../demos/cloth/world.bend as W
import ../../demos/cloth/view.bend as V
import ../../demos/cloth/input.bend as Input
import ../../demos/cloth/contact.bend as G
import ../../engine/spatial.bend as Spatial
import ../../engine/spatial/layout.bend as L
import ../../engine/render/mesh.bend as M
import ../../engine/geometry/grid_surface.bend as Grid

# Browser boundary for the native solver: Result errors return to the host
# instead of exiting an OS process through IO. Constraint/contact math is shared.
# Coarser spatial bins cover the same 8x8x8 domain. A web-sized cloth has
# longer edges and a larger contact query radius; quarter-unit native bins
# spend most of their time visiting empty cells. Every neighbor is retained.
def space() -> L.Layout:
  L.Layout{3,3n,3n,3n,1.0,F32.neg(4.0),F32.neg(2.0),F32.neg(4.0),False{}}
type Simulation is Type:
  Simulation{side: U32, current: W.Positions, previous: W.Positions, scratch: W.Positions,
    index: Spatial.Index(space()), samples: Array<Surface.Sample>, checks: Nat, neighbors: Nat}
type State is Type:
  State{simulation: Simulation, triangles: Array<M.Triangle>, visual: W.Positions}
def created(r: Result<String,Spatial.Index(space())>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: Done{State{Simulation{8,W.create(3n),W.create(3n),W.empty(6n),index,Array.new(Surface.Sample,6n,Surface.blank()),0n,0n},Array.new(M.Triangle,9n,M.blank()),W.empty(8n)}}
def create() -> Result<String,State>: created(Spatial.create(~space(),6n))
def released(side: U32, r: Surface.Source & W.Positions & Spatial.Index(space()) & Spatial.Statistics) -> Simulation:
  (Surface.Source{scratch,previous,samples,_},current,index,Spatial.Statistics{checks,neighbors}) = r
  Simulation{side,current,previous,scratch,index,samples,checks,neighbors}
def collided(side: U32, r: Result<String,Spatial.Step(space(),Surface.Source,W.Positions)>) -> Result<String,Simulation>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: Done{released(side,Spatial.release(~space(),~Surface.Source,~W.Positions,s))}
def built(+side: U32, c: P.Controls, scratch: W.Positions,
  r: Result<String,Spatial.Snapshot(space(),Surface.Source)>) -> Result<String,Simulation>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: collided(side,Spatial.stencil(~space(),~Surface.Source,~W.Positions,~Surface.Sample,~G.Push,~P.Controls,
      ~Surface.read,~Surface.point,~Surface.begin,~Surface.visit,~Surface.finish,~Surface.join,~W.join,
      False{},0n,(3.6 / U32.to_f32((side - 1 : U32)) * 2.8 + 0.08 : F32),False{},c,s,scratch))
def relaxed(+side: U32, previous: W.Positions, index: Spatial.Index(space()), samples: Array<Surface.Sample>, r: P.Relaxation) -> Result<String,Simulation>:
  P.Relaxation{scratch,current,c} = r
  built(side,c,scratch,Spatial.build(~space(),~Surface.Source,~Surface.position,~Surface.join,False{},0n,(side * side : U32),
    Surface.cache_run(False{},0n,(side * side : U32),Surface.Source{current,previous,samples,side}),index))
def predicted(+side: U32, index: Spatial.Index(space()), samples: Array<Surface.Sample>, r: P.Prediction) -> Result<String,Simulation>:
  P.Prediction{previous,scratch,current,c} = r
  relaxed(side,previous,index,samples,S.relaxations(12n,False{},0n,(side * side : U32),P.Relaxation{scratch,current,c}))
def substep(c: P.Controls, s: Simulation) -> Result<String,Simulation>:
  Simulation{+side,current,previous,scratch,index,samples,_,_} = s
  predicted(side,index,samples,P.predict_run(False{},0n,(side * side : U32),P.Prediction{current,previous,scratch,c}))
def second(c: P.Controls, r: Result<String,Simulation>) -> Result<String,Simulation>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: substep(c,s)
def physical(on: Bool, +c: P.Controls, s: Simulation) -> Result<String,Simulation>:
  match on:
    case False{}: Done{s}
    case True{}: second(c,substep(c,s))
type Resample is Type:
  Resample{source: W.Positions, visual: W.Positions}
def sampled(i: U32, visual: W.Positions, r: W.Positions & Grid.Sample) -> Resample:
  (source,Grid.Sample{point,_,_}) = r
  Resample{source,W.write(i,visual,P.contact(point))}
def sample(n: Nat, +i: U32, r: Resample) -> Resample:
  match n:
    case 0n: r
    case 1n+k:
      Resample{source,visual} = r
      sample(k,(i + 1 : U32),sampled(i,visual,Grid.sample(~W.Positions,~W.read,8,
        (U32.to_f32((i % 16 : U32)) * 7.0 / 15.0 : F32),(U32.to_f32((i / 16 : U32)) * 7.0 / 15.0 : F32),source)))
def projected(state: Simulation, r: V.Projection) -> State:
  V.Projection{visual,tris,_,_} = r
  State{state,tris,visual}
def resampled(side: U32, previous: W.Positions, scratch: W.Positions, index: Spatial.Index(space()), samples: Array<Surface.Sample>, checks: Nat, neighbors: Nat, tris: Array<M.Triangle>, r: Resample) -> State:
  Resample{current,visual} = r
  projected(Simulation{side,current,previous,scratch,index,samples,checks,neighbors},V.triangles_run(False{},450,V.Projection{visual,tris,16,False{}}))
def scene(state: State) -> State:
  State{Simulation{side,current,previous,scratch,index,samples,checks,neighbors},tris,visual} = state
  resampled(side,previous,scratch,index,samples,checks,neighbors,tris,sample(256n,0,Resample{current,visual}))
def stepped(tris: Array<M.Triangle>, visual: W.Positions, r: Result<String,Simulation>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: Done{State{s,tris,visual}}
def drawn(r: Result<String,State>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: Done{scene(s)}
def control(time: F32, wind: Bool, id: U32, target: L.Point) -> P.Controls:
  L.Point{x,y,z} = target
  P.Controls{8,id,F32.clamp(x,F32.neg(3.5),3.5),F32.clamp(y,F32.neg(1.5),3.0),F32.clamp(z,F32.neg(3.5),3.5),time,L.pick(wind,1.5,0.0)}
def frame(time: F32, wind: Bool, id: U32, x: F32, y: F32, depth: F32, run: Bool, s: State) -> Result<String,State>:
  State{state,tris,visual} = s
  drawn(stepped(tris,visual,physical(run,control(time,wind,id,V.target(x,y,depth)),state)))
def picked(previous: W.Positions, scratch: W.Positions, index: Spatial.Index(space()), samples: Array<Surface.Sample>, checks: Nat, neighbors: Nat, tris: Array<M.Triangle>, visual: W.Positions, r: W.Positions & Input.Pick) -> State & Input.Pick:
  (current,pick) = r
  (State{Simulation{8,current,previous,scratch,index,samples,checks,neighbors},tris,visual},pick)
def pick(x: F32, y: F32, s: State) -> State & Input.Pick:
  State{Simulation{side,current,previous,scratch,index,samples,checks,neighbors},tris,visual} = s
  picked(previous,scratch,index,samples,checks,neighbors,tris,visual,Input.pick(64,x,y,current))
def background(x: U32, y: U32) -> M.Fragment: V.background(x,y)
