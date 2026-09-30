import Base
import ../../demos/turn/hints.bend as H
import ../../demos/turn/play.bend as P
import ../../demos/turn/model.bend as M
import ../../demos/turn/physics.bend as F
import ../../demos/turn/render.bend as R
import ../../engine/core/time.bend as Time

def frames(n: Nat, +i: U32, r: R.Renderer & Image) -> R.Renderer & Image:
  match n:
    case 0n: r
    case 1n+k:
      (renderer,image) = r
      p = {P.Play{0,M.XY{},F.Body{M.Point{3584,3328,512},2048,2048,8,0,0},(i * P.rotation_ticks() / 24 + 1 : U32),0,120,1,0,False{},0.0,0,0,False{},0,0,0,H.empty()} : P.Play}
      frames(k,(i + 1 : U32),R.frame(False{},p,renderer,image))
def measured(start: Nat, r: R.Renderer & Image) -> IO(Unit):
  (R.Renderer{_,_,pixels,_},_) = r
  do IO<Unit>:
    end : Nat <- Time.micros()
    IO.print("25 native rotation frames, microseconds: " ++ U32.show(Time.elapsed(start,end)))
def ready(r: R.Renderer & Image) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- Time.micros()
    measured(start,frames(25n,0,r))
def main() -> IO(Unit):
  ready(R.frame(False{},P.create(0),R.create(),Pix{0}))
