import Base
import ../web/adapters/cloth.bend as Web
import ../demos/cloth/simulation.bend as S
import ../demos/cloth/world.bend as W
import ../demos/cloth/view.bend as V
import ../engine/spatial.bend as Spatial
import ../engine/spatial/layout.bend as L

def native_steps(n: Nat, +tick: U32, state: S.State) -> IO(S.State):
  match n:
    case 0n: IO.pure(S.State,state)
    case 1n+k:
      do IO<S.State>:
        state : S.State <- S.step(False{},0n,Web.control((U32.to_f32(tick) / 120.0 : F32),True{},4294967295,V.target(256.0,256.0,7.5)),state)
        native_steps(k,(tick + 1 : U32),state)
def web_steps(n: Nat, +tick: U32, state: Web.State) -> IO(Web.State):
  match n:
    case 0n: IO.pure(Web.State,state)
    case 1n+k:
      do IO<Web.State>:
        state : Web.State <- Spatial.require(~Web.State,Web.frame((U32.to_f32(tick) / 120.0 : F32),True{},4294967295,256.0,256.0,7.5,True{},state))
        web_steps(k,(tick + 1 : U32),state)
def point_error(a: L.Point, b: L.Point) -> F32:
  L.Point{x,y,z} = a
  L.Point{u,v,w} = b
  F32.max(F32.abs((x - u : F32)),F32.max(F32.abs((y - v : F32)),F32.abs((z - w : F32))))
def compared(n: Nat, +i: U32, worst: F32, a: W.Positions & L.Point, b: W.Positions & L.Point) -> F32:
  match n:
    case 0n:
      (_,ap) = a
      (_,bp) = b
      F32.max(worst,point_error(ap,bp))
    case 1n+k:
      (aa,ap) = a
      (bb,bp) = b
      compared(k,(i + 1 : U32),F32.max(worst,point_error(ap,bp)),W.read(i,aa),W.read(i,bb))
def error(a: S.State, b: Web.State) -> F32:
  S.State{_,current,_,_,_,_,_,_} = a
  Web.State{Web.Simulation{_,other,_,_,_,_,_,_},_,_} = b
  compared(63n,1,0.0,W.read(0,current),W.read(0,other))
def report(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS: web cloth adapter matches native physics, all 64 vertices after 8 fixed steps.")
    case False{}: IO.die(Unit,1,"Web cloth diverged from native physics.")
def main() -> IO(Unit):
  do IO<Unit>:
    a : S.State <- Spatial.require(~S.State,S.create(3n))
    b : Web.State <- Spatial.require(~Web.State,Web.create())
    a : S.State <- native_steps(8n,0,a)
    b : Web.State <- web_steps(8n,0,b)
    report((error(a,b) < 0.0001 : F32))
