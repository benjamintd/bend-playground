import Base
import ./life.bend as B
import ./image_dump.bend as Dump
import ../demos/life/main.bend as App

def result(r: App.State & Image) -> IO(Unit):
  (App.State{_,_,pixels,_},_) = r
  Dump.image(1024,pixels)
def main() -> IO(Unit):
  do IO<Unit>:
    s : App.State <- App.create(1,42)
    r : App.State & Image <- B.frames(False{},True{},False{},600n,0,4294967295,(s,Pix{0}))
    result(r)
