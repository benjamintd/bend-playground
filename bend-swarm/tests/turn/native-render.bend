import Base
import ../../demos/turn/hints.bend as H
import ../../demos/turn/model.bend as M
import ../../demos/turn/physics.bend as F
import ../../demos/turn/play.bend as P
import ../../demos/turn/render.bend as Render
import ../../engine/render/batch.bend as B

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit,1,"FAIL " ++ name)
    case True{}: IO.print("PASS " ++ name)
def frame_state(i: U32) -> P.Play:
  P.Play{0,M.XY{},F.Body{M.Point{3584,3328,512},2048,2048,8,0,0},
    (i * P.rotation_ticks() / 24 + 1 : U32),0,120,1,0,False{},0.0,0,0,False{},0,0,0,H.empty()}
def repeat_render(n: Nat, +i: U32, r: Render.Renderer & Image) -> Render.Renderer & Image:
  match n:
    case 0n: r
    case 1n+k:
      (renderer,image) = r
      repeat_render(k,(i + 1 : U32),Render.frame(False{},frame_state(i),renderer,image))
def equal_pixels(n: Nat, +i: U32, a: Array<U32> & U32, b: Array<U32> & U32) -> Bool:
  match n:
    case 0n: True{}
    case 1n+k:
      (left,x) = a
      (right,y) = b
      U32.is_eq(x,y) && equal_pixels(k,(i + 1 : U32),Array.get(U32,left,(i + 1 : U32)),Array.get(U32,right,(i + 1 : U32)))
def rendered(a: Render.Renderer & Image, b: Render.Renderer & Image) -> IO(Unit):
  (Render.Renderer{B.Batch{_,+n,+capacity},_,left,_},_) = a
  (Render.Renderer{B.Batch{_,expected,_},_,right,_},_) = b
  check("25 native frames / grown persistent buffers match fresh render at every pixel",
    U32.is_eq(n,expected) && (capacity >= n : U32)
      && equal_pixels(1048576n,0,Array.get(U32,left,0),Array.get(U32,right,0)))
def small(renderer: Render.Renderer) -> Render.Renderer:
  Render.Renderer{_,index,pixels,fragments} = renderer
  Render.Renderer{B.create(1),index,pixels,fragments}
def main() -> IO(Unit):
  rendered(repeat_render(25n,0,(small(Render.create()),Pix{0})),Render.frame(False{},frame_state(24),Render.create(),Pix{0}))
