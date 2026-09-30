import Base
import ./play.bend as P
import ./physics.bend as F
import ./tempo.bend as T
import ../../engine/platform/events.bend as Events

# Game policy: paused when inactive, static menus, 30 Hz decoration at rest,
# 60 Hz while moving/turning. Physics still advances with its fixed 120 Hz tick.
def active(activity: Events.Activity) -> Bool:
  Events.Activity{focused,visible,_} = activity
  focused && visible
def continuous(activity: Events.Activity) -> Bool:
  Events.Activity{_,_,interrupted} = activity
  Bool.not(interrupted)
def suspend(p: P.Play) -> P.Play:
  P.Play{l,plane,F.Body{q,vx,vy,c,_,escape},t,s,clock,v,_,quit,_,f,seals,menu,selection,completed,pace,hints} = p
  P.Play{l,plane,F.Body{q,vx,vy,c,0,escape},t,s,clock,v,0,quit,0.0,f,seals,menu,selection,completed,pace,hints}
def period(p: P.Play) -> U32:
  P.Play{_,_,F.Body{_,vx,vy,_,buffer,escape},turn,_,_,_,keys,_,_,finished,_,menu,_,_,+pace,hints} = p
  Bool.pick(U32,menu,0,Bool.pick(U32,U32.is_ne(turn,0) || U32.is_ne(finished,0),16667,
    Bool.pick(U32,T.frozen(pace),0,Bool.pick(U32,U32.is_ne(pace,0) || U32.is_ne(keys,0) || U32.is_ne(vx,2048) || U32.is_ne(vy,2048)
      || U32.is_ne(buffer,0) || U32.is_ne(escape,0),16667,33334))))

def event(e: Event, active: Bool, p: P.Play, dirty: Bool) -> P.Play & Bool:
  match e:
    case Close{}: (P.quit(p),dirty)
    case Key{code,down}:
      match active:
        case False{}: (p,dirty)
        case True{}: (P.key(code,down,p),True{})
    case _: (p,dirty)
def input(es: List<Event>, +active: Bool, r: P.Play & Bool) -> P.Play & Bool:
  match es:
    case Nil{}: r
    case e <> rest:
      (p,dirty) = r
      input(rest,active,event(e,active,p,dirty))
def elapsed(active: Bool, was_active: Bool, dt: F32, p: P.Play) -> P.Play:
  match active was_active:
    case True{} True{}: P.tick(dt,p)
    case _ _: suspend(p)
