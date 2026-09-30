import Base
import ./play.bend as P
import ./view.bend as V
import ./schedule.bend as Schedule
import ./hints.bend as H
import ./levels.bend as L
import ../../engine/render/batch.bend as B
import ../../engine/render/mesh.bend as M

def create(level: U32) -> P.Play: P.create(U32.min(level,25))
def key(code: U32, down: Bool, p: P.Play) -> P.Play: P.key(code,down,p)
def tick(dt: F32, p: P.Play) -> P.Play: P.tick(dt,p)
def suspend(p: P.Play) -> P.Play: Schedule.suspend(p)
def period(p: P.Play) -> U32: Schedule.period(p)
def batch() -> B.Batch: B.create(32768)
def scene(p: P.Play, b: B.Batch) -> B.Batch: V.scene(p,b)
def background(x: U32, y: U32) -> M.Fragment: V.background(x,y)
def remaining(p: P.Play) -> U32:
  P.Play{_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,hints} = p
  (3 - H.count(hints) : U32)
def title(p: P.Play) -> String:
  P.Play{level,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_} = p
  L.title(level)
