import Base
import ./model.bend as M
import ./levels.bend as L
import ./collision.bend as C

# Explicit cell coordinates avoid repeated symbolic index arithmetic during
# proof reduction. catalog.js checks that this is exactly the complete 10x10
# grid; every target is still obtained from the actual planning resolver.
def grid() -> List<M.Point>:
  [
    M.Point{0,0,0},M.Point{1,0,0},M.Point{2,0,0},M.Point{3,0,0},M.Point{4,0,0},M.Point{5,0,0},M.Point{6,0,0},M.Point{7,0,0},M.Point{8,0,0},M.Point{9,0,0},
    M.Point{0,1,0},M.Point{1,1,0},M.Point{2,1,0},M.Point{3,1,0},M.Point{4,1,0},M.Point{5,1,0},M.Point{6,1,0},M.Point{7,1,0},M.Point{8,1,0},M.Point{9,1,0},
    M.Point{0,2,0},M.Point{1,2,0},M.Point{2,2,0},M.Point{3,2,0},M.Point{4,2,0},M.Point{5,2,0},M.Point{6,2,0},M.Point{7,2,0},M.Point{8,2,0},M.Point{9,2,0},
    M.Point{0,3,0},M.Point{1,3,0},M.Point{2,3,0},M.Point{3,3,0},M.Point{4,3,0},M.Point{5,3,0},M.Point{6,3,0},M.Point{7,3,0},M.Point{8,3,0},M.Point{9,3,0},
    M.Point{0,4,0},M.Point{1,4,0},M.Point{2,4,0},M.Point{3,4,0},M.Point{4,4,0},M.Point{5,4,0},M.Point{6,4,0},M.Point{7,4,0},M.Point{8,4,0},M.Point{9,4,0},
    M.Point{0,5,0},M.Point{1,5,0},M.Point{2,5,0},M.Point{3,5,0},M.Point{4,5,0},M.Point{5,5,0},M.Point{6,5,0},M.Point{7,5,0},M.Point{8,5,0},M.Point{9,5,0},
    M.Point{0,6,0},M.Point{1,6,0},M.Point{2,6,0},M.Point{3,6,0},M.Point{4,6,0},M.Point{5,6,0},M.Point{6,6,0},M.Point{7,6,0},M.Point{8,6,0},M.Point{9,6,0},
    M.Point{0,7,0},M.Point{1,7,0},M.Point{2,7,0},M.Point{3,7,0},M.Point{4,7,0},M.Point{5,7,0},M.Point{6,7,0},M.Point{7,7,0},M.Point{8,7,0},M.Point{9,7,0},
    M.Point{0,8,0},M.Point{1,8,0},M.Point{2,8,0},M.Point{3,8,0},M.Point{4,8,0},M.Point{5,8,0},M.Point{6,8,0},M.Point{7,8,0},M.Point{8,8,0},M.Point{9,8,0},
    M.Point{0,9,0},M.Point{1,9,0},M.Point{2,9,0},M.Point{3,9,0},M.Point{4,9,0},M.Point{5,9,0},M.Point{6,9,0},M.Point{7,9,0},M.Point{8,9,0},M.Point{9,9,0} ]
def cells(+level: U32, +plane: M.Plane, qs: List<M.Point>) -> Bool:
  match qs:
    case Nil{}: True{}
    case q <> rest:
      L.projected_free(level,plane,C.cell(level,plane,M.world(plane,q))) && cells(level,plane,rest)
def level(+id: U32) -> Bool:
  cells(id,M.XY{},grid()) && cells(id,M.YZ{},grid()) && cells(id,M.ZX{},grid())
