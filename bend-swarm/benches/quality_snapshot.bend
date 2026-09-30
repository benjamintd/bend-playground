import Base
import ../engine/platform/arguments.bend as Arguments
import ../demos/meadow/main.bend as App
import ../demos/meadow/scene.bend as Scene
import ../engine/platform/player.bend as Player
import ./image_dump.bend as Dump

# Freeze the same seeded state for every quality comparison. Warm physics only,
# so exports do not pay for 120 discarded full-resolution images.
def warm(n: Nat, +tick: U32, s: App.State) -> App.State:
  match n:
    case 0n: s
    case 1n+k:
      App.State{blades,tris,index,pixels,fragments,high} = s
      warm(k,(tick + 1 : U32),App.State{Scene.simulate(False{},False{},Scene.controls((U32.to_f32(tick) / 60.0 : F32),1,0.0,Scene.mouse(0.5,0.5)),blades),tris,index,pixels,fragments,high})
def result(+high: Bool, r: App.State & Image & Player.Metrics) -> IO(Unit):
  (App.State{_,_,_,pixels,_,_},_,_) = r
  do IO<Unit>:
    Unit <- IO.print(Bool.pick(String,high,"P3\n2048 2048\n255","P3\n1024 1024\n255"))
    Dump.rows(64,Bool.pick(Nat,high,65536n,16384n),0,pixels)
def render(aa: Bool, dof: Bool, +high: Bool) -> IO(Unit):
  do IO<Unit>:
    s : App.State <- App.create(1,42)
    r : App.State & Image & Player.Metrics <- App.frame(Player.Input{False{},True{},False{},False{},False{},1,42,0.5,0.5,0.0,2.0,aa,dof,high},warm(120n,0,s),Pix{0})
    result(high,r)
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case "raw" <> Nil{}: render(False{},False{},False{})
    case "dof" <> Nil{}: render(True{},True{},False{})
    case "high" <> Nil{}: render(True{},False{},True{})
    case "dof" <> "high" <> Nil{}: render(True{},True{},True{})
    case _: render(True{},False{},False{})
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
