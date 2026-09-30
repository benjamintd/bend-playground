import Base

# Wall-clock ticks at 120 Hz. 0 = normal, 1 = frozen, 2..61 = a
# half-second smoothstep back to full speed. Physics keeps fixed-size steps.
def frozen(pace: U32) -> Bool: U32.is_eq(pace,1)
def release(+pace: U32) -> U32:
  match pace:
    case 1: 2
    case _: pace
def rate(pace: U32) -> U32:
  match pace:
    case 0: 100
    case 1: 0
    case _:
      +age = U32.min(60,(pace - 1 : U32))
      (age * age * (180 - 2 * age) * 100 / 216000 : U32)
def next(+pace: U32) -> U32:
  match pace:
    case 0: 0
    case 1: 1
    case _:
      Bool.pick(U32,(pace >= 61 : U32),0,(pace + 1 : U32))
def advance(n: Nat, pace: U32) -> U32:
  match n:
    case 0n: pace
    case 1n+k: advance(k,next(pace))
type Pulse is Data:
  Pulse{run: Bool, phase: U32, pace: U32}
def running(+pace: U32, phase: U32) -> Pulse:
  +sum = (phase + rate(pace) : U32)
  Pulse{(sum >= 100 : U32),(sum % 100 : U32),next(pace)}
def waiting(held: Bool, pace: U32, phase: U32) -> Pulse:
  match held:
    case True{}: Pulse{False{},0,pace}
    case False{}: running(pace,phase)
def pulse(turning: Bool, +pace: U32, phase: U32) -> Pulse:
  match turning:
    case True{}: Pulse{False{},0,pace}
    case False{}: waiting(frozen(pace),pace,phase)
