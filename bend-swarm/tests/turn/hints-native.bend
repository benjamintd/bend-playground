import Base
import ../../demos/turn/play.bend as P
import ../../demos/turn/hints.bend as H
import ../../demos/turn/physics.bend as F
import ../../demos/turn/model.bend as M

def press(+code: U32, p: P.Play) -> P.Play: P.key(code,False{},P.key(code,True{},p))
def used(p: P.Play) -> U32:
  P.Play{_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,h} = p
  H.count(h)
def position(p: P.Play) -> M.Point:
  P.Play{_,_,b,_,_,_,_,_,_,_,_,_,_,_,_,_,_} = p
  F.position(b)
def check(+p: P.Play) -> Bool:
  U32.is_eq(used(p),1) && U32.is_eq(used(press(104,p)),1) && U32.is_eq(used(P.reset(p)),1)
    && M.equal(position(p),F.position(F.initial())) && U32.is_eq(used(P.load(4,p)),0)
def report(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS: native hint input, free repeat, reset persistence, chapter refill, and unchanged player position.")
    case False{}: IO.die(Unit,1,"Native hints failed.")
def main() -> IO(Unit): report(check(press(104,P.create(3))))
