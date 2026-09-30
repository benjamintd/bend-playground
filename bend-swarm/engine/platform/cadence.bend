import Base

# Shared event-driven frame scheduling. A zero interval means a static scene:
# draw only when dirty. age_us is time since the last rendered frame.
# Sleeping is bounded to one second and input/lifecycle events may wake sooner.
def due(active: Bool, dirty: Bool, +interval_us: U32, age_us: U32) -> Bool:
  active && (dirty || (U32.is_ne(interval_us,0) && (age_us >= interval_us : U32)))
def remaining_ms(+interval_us: U32, age_us: U32) -> U32:
  +remaining = (interval_us - U32.min(age_us,interval_us) : U32)
  U32.min(1000,(remaining / 1000 + Bool.to_u32(U32.is_ne((remaining % 1000 : U32),0)) : U32))
def wait_ms(active: Bool, dirty: Bool, +interval_us: U32, age_us: U32) -> U32:
  Bool.pick(U32,active,
    Bool.pick(U32,dirty,0,Bool.pick(U32,U32.is_eq(interval_us,0),1000,remaining_ms(interval_us,age_us))),1000)
