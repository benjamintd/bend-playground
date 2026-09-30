import Base
import ../../demos/turn/play.bend as P
import ../../demos/turn/render.bend as R
import ../../engine/core/time.bend as Time
import ../../engine/platform/viewport.bend as Viewport
import ./visual-bench.bend as Bench

type Run is Type:
  Run{window: Window, renderer: R.Renderer, image: Image}
def presented(renderer: R.Renderer, result: Window & Image & List<Event>) -> Run:
  (w,image,_) = result
  Run{w,renderer,image}
def present(w: Window, result: R.Renderer & Image) -> IO(Run):
  (renderer,image) = result
  do IO<Run>:
    result : Window & Image & List<Event> <- Window.frame(w,image)
    return presented(renderer,result)
def frames(n: Nat, +i: U32, run: Run) -> IO(Run):
  match n:
    case 0n: IO.pure(Run,run)
    case 1n+k:
      Run{w,renderer,image} = run
      do IO<Run>:
        next : Run <- present(w,Bench.frames(1n,(i % 25 : U32),(renderer,image)))
        frames(k,(i + 1 : U32),next)
def finish(start: Nat, run: Run) -> IO(Unit):
  Run{w,_,_} = run
  do IO<Unit>:
    end : Nat <- Time.micros()
    Unit <- IO.print("120 frames including native presentation, microseconds: " ++ U32.show(Time.elapsed(start,end)))
    Window.close(w)
def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("TURN frame benchmark",760,760))
    w : Window <- Viewport.resolution(w,1024)
    ready : Run <- frames(25n,0,Run{w,R.create(),Pix{0}})
    start : Nat <- Time.micros()
    run : Run <- frames(120n,0,ready)
    finish(start,run)
