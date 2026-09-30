import Base
import ./hints.bend as H
import ./play.bend as P
import ./levels.bend as L
import ./physics.bend as F
import ./render.bend as R
import ./model.bend as M
import ../../benches/image_dump.bend as Dump

def sample(turn: U32) -> P.Play:
  P.Play{0,M.XY{},F.Body{M.Point{3584,3328,512},2048,2048,8,0,0},turn,0,120,1,0,False{},0.0,0,0,False{},0,0,0,H.empty()}
# Completed-state fixtures use positions verified by the native input replays.
def completed_point(level: U32) -> M.Point:
  match level:
    case 0: M.Point{9484,9894,512}
    case 1: M.Point{9484,9894,512}
    case 2: M.Point{9732,9488,512}
    case 3: M.Point{9472,8960,9489}
    case 4: M.Point{9472,9750,9474}
    case 5: M.Point{9954,9715,6660}
    case 6: M.Point{9472,1888,9474}
    case 7: M.Point{9954,9714,256}
    case 8: M.Point{9472,9744,1891}
    case 9: M.Point{1888,9942,9710}
    case 10: M.Point{1888,9472,9472}
    case 11: M.Point{9954,9734,1891}
    case 12: M.Point{7702,9479,9472}
    case 13: M.Point{1888,9495,9472}
    case 14: M.Point{9954,9738,1891}
    case 15: M.Point{9942,9733,1888}
    case 16: M.Point{9472,1891,9483}
    case 17: M.Point{9478,9964,497}
    case 18: M.Point{9816,9750,5636}
    case 19: M.Point{9476,9972,256}
    case 20: M.Point{9496,9472,8960}
    case 21: M.Point{9715,256,9816}
    case 22: M.Point{9475,9472,2815}
    case 23: M.Point{9472,7936,9484}
    case 24: M.Point{9472,512,9472}
    case 25: M.Point{9472,256,9484}
    case _: M.Point{9728,9728,512}
def completed_plane(level: U32) -> M.Plane:
  match level:
    case 0: M.XY{}
    case 1: M.XY{}
    case 2: M.XY{}
    case 3: M.ZX{}
    case 4: M.ZX{}
    case 5: M.XY{}
    case 6: M.ZX{}
    case 7: M.XY{}
    case 8: M.XY{}
    case 9: M.YZ{}
    case 10: M.YZ{}
    case 11: M.XY{}
    case 12: M.YZ{}
    case 13: M.YZ{}
    case 14: M.XY{}
    case 15: M.XY{}
    case 16: M.ZX{}
    case 17: M.XY{}
    case 18: M.XY{}
    case 19: M.XY{}
    case 20: M.XY{}
    case 21: M.ZX{}
    case 22: M.XY{}
    case 23: M.ZX{}
    case 24: M.ZX{}
    case 25: M.ZX{}
    case _: M.XY{}
def complete(+level: U32) -> P.Play:
  P.Play{level,completed_plane(level),F.Body{completed_point(level),2048,2048,0,0,0},0,0,1200,L.par(level),0,False{},0.0,60,L.all_seals(level),False{},L.index(level),L.flag(level),0,H.empty()}
def room_sample() -> P.Play:
  P.Play{23,M.XY{},F.Body{M.Point{3584,8448,8704},2048,2048,0,0,0},0,0,720,3,0,False{},0.0,0,3,False{},23,0,0,H.empty()}
def dump(r: R.Renderer & Image) -> IO(Unit):
  (R.Renderer{_,_,pixels,_},_) = r
  # PPM allows arbitrary whitespace. Short lines avoid quadratic String
  # append work while retaining every pixel of the 1024-square render.
  do IO<Unit>:
    Unit <- IO.print("P3\n1024 1024\n255")
    Dump.rows(64,16384n,0,pixels)
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case "menu" <> Nil{}: dump(R.frame(False{},P.toggle(P.create(17)),R.create(),Pix{0}))
    case "rooms" <> Nil{}: dump(R.frame(False{},P.toggle(P.create(18)),R.create(),Pix{0}))
    case "rings" <> Nil{}: dump(R.frame(False{},P.create(18),R.create(),Pix{0}))
    case "frozen" <> Nil{}: dump(R.frame(False{},P.steps(90n,P.command(114,P.create(0))),R.create(),Pix{0}))
    case "resuming" <> Nil{}: dump(R.frame(False{},P.steps(30n,P.command(63233,P.steps(90n,P.command(114,P.create(0))))),R.create(),Pix{0}))
    case "settling" <> Nil{}: dump(R.frame(False{},P.steps(70n,P.command(63233,P.steps(90n,P.command(114,P.create(0))))),R.create(),Pix{0}))
    case "keyhole" <> Nil{}: dump(R.frame(False{},room_sample(),R.create(),Pix{0}))
    case "relay" <> Nil{}: dump(R.frame(False{},P.create(17),R.create(),Pix{0}))
    case "turn" <> Nil{}: dump(R.frame(False{},sample(43),R.create(),Pix{0}))
    case "end" <> Nil{}: dump(R.frame(False{},sample(85),R.create(),Pix{0}))
    case "win" <> Nil{}: dump(R.frame(False{},complete(L.at(0)),R.create(),Pix{0}))
    case "complete" <> Nil{}: dump(R.frame(False{},complete(17),R.create(),Pix{0}))
    case "jump" <> Nil{}: dump(R.frame(False{},P.steps(30n,P.key(100,True{},P.command(32,P.create(L.at(0))))),R.create(),Pix{0}))
    case _: dump(R.frame(False{},P.create(L.at(0)),R.create(),Pix{0}))
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
