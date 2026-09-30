import Base
import ./replay.bend as Replay
import ../../demos/turn/model.bend as M
import ../../demos/turn/physics.bend as F
import ../../demos/turn/play.bend as P
import ../../demos/turn/levels.bend as L

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit,1,"FAIL " ++ name)
    case True{}: IO.print("PASS " ++ name)
def completed(+p: P.Play, expected: M.Point) -> Bool:
  P.Play{+level,plane,+body,_,_,_,turns,_,_,_,_,seals,_,_,_,pace,hints} = p
  P.arrived(p) && F.clear(level,plane,F.position(body)) && M.equal(F.position(body),expected)
    && U32.is_eq(seals,L.all_seals(level)) && (turns <= L.par(level) : U32)
def progressed(p: P.Play, expected: U32) -> Bool:
  P.Play{level,_,body,_,_,_,turns,keys,_,_,finished,_,_,_,_,pace,hints} = p
  U32.is_eq(level,expected) && M.equal(F.position(body),F.position(F.initial()))
    && U32.is_eq(turns,0) && U32.is_eq(keys,0) && U32.is_eq(finished,0)
def jumped_right(p: P.Play) -> Bool:
  P.Play{_,_,F.Body{M.Point{x,y,_},_,_,_,_,_},_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  (x > 512 : U32) && (y > 256 : U32)
# Route data enters at runtime, avoiding a giant compiled constant fixture.
# One word packs 16 tick bits, 4 held-key bits, then jump and turn flags.
def number(value: Maybe<&2, U32>) -> U32:
  match value:
    case Some{n}: n
    case None{}: 0
def decode(+word: U32) -> Replay.Run:
  Replay.Run{U32.to_nat(U32.and(word,65535)),U32.and(U32.shrn(word,16n),15),
    P.down(word,1048576),P.down(word,2097152)}
def input(runs: List<String>, p: P.Play) -> P.Play:
  match runs:
    case Nil{}: p
    case run <> rest: input(rest,Replay.run(decode(number(U32.read(run))),p))
def after_exit(last: Bool, +level: U32, expected: M.Point, p: P.Play) -> IO(Unit):
  match last:
    case True{}: check(L.title(level) ++ " / final completion stays",completed(p,expected))
    case False{}: check(L.title(level) ++ " / automatic progression",progressed(p,L.next(level)))
def chapter_result(+level: U32, +expected: M.Point, elapsed: U32, +p: P.Play) -> IO(Unit):
  do IO<Unit>:
    Unit <- check(L.title(level) ++ " / native route, all seals, turn target",completed(p,expected))
    after_exit(L.last(level),level,expected,P.steps(U32.to_nat(elapsed),p))
def chapter(+level: U32, expected: M.Point, elapsed: U32, runs: List<String>) -> IO(Unit):
  chapter_result(level,expected,elapsed,input(runs,P.create(level)))
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case level <> x <> y <> z <> elapsed <> runs:
      chapter(number(U32.read(level)),M.Point{number(U32.read(x)),number(U32.read(y)),number(U32.read(z))},number(U32.read(elapsed)),runs)
    case _: IO.die(Unit,1,"Expected level, final x y z, completion ticks and packed input runs")
def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- check("native Up and Right arrow events jump and move",jumped_right(P.steps(4n,P.events([Key{63235,True{}},Key{63232,True{}}],P.create(0)))))
    xs : List<String> <- IO.args()
    args(xs)
