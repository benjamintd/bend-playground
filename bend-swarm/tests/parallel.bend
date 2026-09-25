import Base
import ../engine/parallel/map.bend as Map
import ../engine/parallel/reduce.bend as Reduce
import ../engine/parallel/scan.bend as Scan

def double(x: U32) -> U32:
  (x * 2 : U32)

def mapped(depth: Nat, a: Array<U32>) -> Array<U32>:
  Map.run(~U32,~double,depth,a)
