import Base
import ../demos/life/main.bend as App
import ../engine/platform/player.bend as Player
import ./image-check.bend as Check

def finished(r: App.State & Image & Player.Metrics) -> App.State & Image:
  (s,image,_) = r
  (s,image)
def frames(n: Nat, r: App.State & Image) -> IO(App.State & Image):
  match n:
    case 0n: IO.pure(App.State & Image,r)
    case 1n+k:
      (s,image) = r
      do IO<App.State & Image>:
        f : App.State & Image & Player.Metrics <- App.frame(Player.Input{True{},False{},False{},False{},False{},1,42,0.5,0.5,0.0,0.0,True{},False{},False{}},s,image)
        frames(k,finished(f))
def report(r: Check.Check) -> IO(Unit):
  Check.Check{_,count,errors} = r
  IO.print(U32.show(count) ++ "," ++ U32.show(errors))
def checked(r: App.State & Image) -> IO(Unit):
  (App.State{_,_,pixels,_},image) = r
  report(Check.image(image,1024,1024,0,0,Check.Check{pixels,0,0}))
def main() -> IO(Unit):
  do IO<Unit>:
    s : App.State <- App.create(1,42)
    r : App.State & Image <- frames(120n,(s,Pix{0}))
    checked(r)
