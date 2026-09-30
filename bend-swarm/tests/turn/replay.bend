import Base
import ../../demos/turn/play.bend as P
import ../../demos/turn/physics.bend as F

type Run is Data:
  Run{ticks: Nat, keys: U32, jump: Bool, turn: Bool}
def press(+code: U32, p: P.Play) -> P.Play:
  P.key(code,False{},P.key(code,True{},p))
def optional(on: Bool, code: U32, p: P.Play) -> P.Play:
  match on:
    case False{}: p
    case True{}: press(code,p)
def held(+keys: U32, p: P.Play) -> P.Play:
  P.key(115,P.down(keys,8),P.key(100,P.down(keys,2),P.key(97,P.down(keys,1),p)))
def run(r: Run, p: P.Play) -> P.Play:
  Run{ticks,keys,jump,turn} = r
  P.steps(ticks,optional(turn,114,optional(jump,32,held(keys,p))))
def replay(runs: List<Run>, p: P.Play) -> P.Play:
  match runs:
    case Nil{}: p
    case r <> rest: replay(rest,run(r,p))
