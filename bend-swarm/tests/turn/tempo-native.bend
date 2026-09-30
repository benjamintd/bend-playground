import Base
import ../../demos/turn/model.bend as M
import ../../demos/turn/physics.bend as F
import ../../demos/turn/play.bend as P
import ./replay.bend as Replay

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit,1,"FAIL " ++ name)
    case True{}: IO.print("PASS " ++ name)
def clock(p: P.Play) -> U32:
  P.Play{_,_,_,_,_,time,_,_,_,_,_,_,_,_,_,_,hints} = p
  time
def position(p: P.Play) -> M.Point:
  P.Play{_,_,body,_,_,_,_,_,_,_,_,_,_,_,_,_,hints} = p
  F.position(body)
def plane(p: P.Play) -> M.Plane:
  P.Play{_,plane,_,_,_,_,_,_,_,_,_,_,_,_,_,_,hints} = p
  plane
def turned(n: Nat, p: P.Play) -> P.Play:
  P.steps(n,Replay.press(114,p))
def chain(+n: Nat, wait: Nat) -> Bool:
  +first = turned(n,P.create(0))
  +held = P.steps(wait,first)
  +second = turned(n,held)
  +third = turned(n,second)
  P.frozen(first) && P.frozen(held) && P.can_turn(held)
    && M.equal(position(first),position(held)) && U32.is_eq(clock(held),0)
    && M.equal(M.local(plane(second),M.Point{1,2,3}),M.Point{3,1,2})
    && M.equal(position(second),F.position(F.initial()))
    && M.equal(M.local(plane(third),M.Point{1,2,3}),M.Point{1,2,3})
    && M.equal(position(third),F.position(F.initial())) && U32.is_eq(clock(third),0)
def resumed(p: P.Play) -> Bool:
  P.Play{_,_,_,_,_,+time,_,_,_,_,_,_,_,_,_,pace,hints} = p
  U32.is_eq(pace,0) && (time >= 29 : U32) && (time <= 31 : U32)
def ramp(n: Nat, ticks: Nat) -> Bool:
  resumed(P.steps(ticks,Replay.press(63233,turned(n,P.create(0)))))
def parsed(n: Maybe<&2, U32>) -> Nat:
  match n:
    case Some{n}: U32.to_nat(n)
    case None{}: 0n
def number(s: String) -> Nat: parsed(U32.read(s))
def run(+turn: Nat, hold: Nat, fade: Nat) -> IO(Unit):
  do IO<Unit>:
    Unit <- check("native XY -> YZ -> ZX -> XY, no intermediate fall, indefinite freeze",chain(turn,hold))
    check("native fresh input restores full speed through a bounded half-second fade",ramp(turn,fade))
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case turn <> hold <> fade <> Nil{}: run(number(turn),number(hold),number(fade))
    case _: IO.die(Unit,64,"expected turn, hold and fade ticks")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
