import Base

# Measured on the M2 Pro; CLI sweeps still override depth. No universal claim.
type ExecutionPlan is Data:
  Plan{fork_depth: Nat, leaf_items: U32}

def for_count(depth: Nat, +count: U32) -> ExecutionPlan:
  +d = Nat.min(depth,U32.log2(count))
  Plan{d,U32.shrn(count,d)}

def default_depth() -> Nat:
  14n
