import Base
import ./engine/parallel/partition.bend as P

# Structural buffer movement; no floating-point or unsafe promises.
law swap_involution:
  for -T: Type
  for buffers: T & T
  {P.swap(T,P.swap(T,buffers)) == buffers : T & T}

law partition_reassembly:
  for -T: Type
  for a: Array<T>
  for b: Array<T>
  {P.merge(T,P.split_node(T,a,b)) == ANode{a,b} : Array<T>}

law capacity_doubles:
  for d: Nat
  {P.capacity(1n+d) == Nat.add(P.capacity(d),P.capacity(d)) : Nat}

law capacity_positive:
  for d: Nat
  exs remainder: Nat
  {P.capacity(d) == 1n+remainder : Nat}
