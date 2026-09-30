import Base
import ../../demos/turn/model.bend as M
import ../../demos/turn/levels.bend as L
import ../../demos/turn/collision.bend as C
import ../../demos/turn/physics.bend as F

# Runtime input bounds keep the exhaustive fixture out of compiler unrolling.
def escaped(b: F.Body) -> U32:
  F.Body{_,_,_,_,_,escape} = b
  escape
def expected(free: Bool, level: U32, +p: M.Plane, q: M.Point) -> U32:
  match free:
    case True{}: 0
    case False{}: F.pack(M.local(p,C.scaled(C.cell(level,p,q))))
def pose(+level: U32, +p: M.Plane, +q: M.Point) -> Bool:
  +body = F.rotated(level,p,F.Body{C.scaled(q),2048,2048,0,0,0})
  M.equal(F.position(body),C.scaled(q))
    && U32.is_eq(escaped(body),expected(L.projected_free(level,p,q),level,p,q))
def cells(+n: Nat, +level: U32, +p: M.Plane) -> Bool:
  match n:
    case 0n: True{}
    case 1n+k:
      +i = U32.from_nat(k)
      pose(level,p,M.world(p,M.Point{(i % 10 : U32),(i / 10 : U32),4})) && cells(k,level,p)
def levels(+n: Nat, +size: Nat) -> Bool:
  match n:
    case 0n: True{}
    case 1n+k:
      +id = U32.from_nat(k)
      cells(size,id,M.XY{}) && cells(size,id,M.YZ{}) && cells(size,id,M.ZX{}) && levels(k,size)
def result(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS: all 7800 native cell-center rotation targets match the proved escape table; camera switches preserve exact position")
    case False{}: IO.die(Unit,1,"FAIL: native rotation/table mismatch")
def number(value: Maybe<&2, U32>) -> U32:
  match value:
    case Some{n}: n
    case None{}: 0
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case count <> size <> Nil{}: result(levels(U32.to_nat(number(U32.read(count))),U32.to_nat(number(U32.read(size)))))
    case _: IO.die(Unit,1,"Expected level count and 100 cell positions")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
