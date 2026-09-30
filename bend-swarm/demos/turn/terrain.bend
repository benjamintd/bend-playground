import Base
import ./model.bend as M

# Sparse, hand-authored 3D staircases and ledges. True means solid.
# Everything else in the ten-cube is empty air.
def between(+n: U32, a: U32, b: U32) -> Bool:
  (n >= a : U32) && (n <= b : U32)
def first(q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (U32.is_eq(z,0) && (y < x : U32))
    || (U32.is_eq(x,9) && (y < 9 : U32) && (z < 9 - y : U32))
    || (U32.is_eq(x,9) && between(y,3,9) && U32.is_eq(z,8))
def second(q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (U32.is_eq(z,0) && (x <= 3 : U32) && (y < x : U32))
    || (U32.is_eq(x,3) && between(y,4,7) && (z < y - 3 : U32))
    || (U32.is_eq(y,7) && between(z,5,9) && (x < U32.min((z - 1 : U32),7) : U32))
    || (U32.is_eq(x,2) && U32.is_eq(y,7) && U32.is_eq(z,4))
    || (U32.is_eq(x,7) && U32.is_eq(y,6) && U32.is_eq(z,9))
    || (U32.is_eq(x,8) && U32.is_eq(y,7) && U32.is_eq(z,9))
    || (U32.is_eq(x,9) && U32.is_eq(y,8) && U32.is_eq(z,9))
    || (between(x,6,8) && U32.is_eq(y,1) && between(z,2,3))
def third(q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (U32.is_eq(z,0) && (x <= 4 : U32) && (y < x : U32))
    || (U32.is_eq(x,4) && (y <= 3 : U32) && (z < 4 - y : U32))
    || (U32.is_eq(y,0) && between(z,5,9) && (x < U32.min(z,8) : U32))
    || (U32.is_eq(x,3) && U32.is_eq(y,0) && U32.is_eq(z,4))
    || (U32.is_eq(z,9) && (x < 8 : U32) && (y < 8 - x : U32))
    || (U32.is_eq(z,9) && between(x,2,9) && U32.is_eq(y,8))
    || (between(x,1,3) && U32.is_eq(y,4) && between(z,3,5))
    || (U32.is_eq(x,7) && between(y,4,6) && U32.is_eq(z,5))

# Sparse supports remain full unit cubes. These constructions describe actual
# world coordinates, never a camera slice or a player-relative layout.
def paper(q: M.Point) -> Bool:
  M.Point{+x,y,z} = q
  U32.is_eq(z,0) && between(x,1,9) && U32.is_eq((y + 1 : U32),x)
def one_turn(q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (U32.is_eq(z,0) && between(x,1,8) && U32.is_eq((y + 1 : U32),x))
    || (U32.is_eq(x,9) && U32.is_eq(y,7) && U32.is_eq(z,0))
    || (U32.is_eq(x,9) && (y < 8 : U32) && U32.is_eq((z + 1 : U32),(8 - y : U32)))
    || (U32.is_eq(x,9) && between(y,2,9) && U32.is_eq(z,8))
def hole(+gaps: U32, +z: U32) -> Bool:
  ((gaps > 0 : U32) && U32.is_eq(z,8)) || (U32.is_eq(gaps,2) && U32.is_eq(z,6))
def chain(+a: U32, +b: U32, gaps: U32, ridge: Bool, canopy: Bool, q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (U32.is_eq(z,0) && between(x,1,a) && U32.is_eq((y + 1 : U32),x))
    || (ridge && U32.is_eq(z,0) && (x > a : U32) && (x < a * 2 : U32) && U32.is_eq((y + 1 : U32),(a * 2 - x : U32)))
    || (canopy && U32.is_eq(z,0) && between(x,7,8) && U32.is_eq(y,1))
    || (U32.is_eq(x,a) && between(y,(a + 1 : U32),b) && U32.is_eq((z + 1 : U32),(y - a : U32)))
    || (U32.is_eq(y,b) && between(z,(b - a + 1 : U32),9) && U32.is_eq((x + 1 : U32),U32.min((a + z - (b - a) : U32),b)) && Bool.not(hole(gaps,z)))
    || (U32.is_eq(x,(a - 1 : U32)) && U32.is_eq(y,b) && U32.is_eq(z,(b - a : U32)))
    || (U32.is_eq(z,9) && between(x,b,9) && U32.is_eq((y + 1 : U32),x))
def switchback(+a: U32, q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (U32.is_eq(z,0) && between(x,1,a) && U32.is_eq((y + 1 : U32),x))
    || (U32.is_eq(x,a) && (y < a : U32) && U32.is_eq((z + 1 : U32),(a - y : U32)))
    || (U32.is_eq(y,0) && between(z,(a + 1 : U32),9) && U32.is_eq((x + 1 : U32),U32.min(z,8)))
    || (U32.is_eq(x,(a - 1 : U32)) && U32.is_eq(y,0) && U32.is_eq(z,a))
    || (U32.is_eq(z,9) && (x < 8 : U32) && U32.is_eq((y + 1 : U32),(8 - x : U32)))
    || (U32.is_eq(z,9) && between(x,2,9) && U32.is_eq(y,8))
