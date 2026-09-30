import Base
import ./play.bend as P
import ./levels.bend as L
import ./render.bend as R
import ./schedule.bend as Schedule
import ../../engine/core/time.bend as Time
import ../../engine/platform/events.bend as Events
import ../../engine/platform/cadence.bend as Cadence
import ../../engine/platform/viewport.bend as Viewport

type Session is Type:
  Session{window: Window, renderer: R.Renderer, image: Image, play: P.Play,
    active: Bool, dirty: Bool, previous: Nat, last_frame: Nat}
def inputs(w: Window, renderer: R.Renderer, image: Image, active: Bool, previous: Nat, last_frame: Nat,
  r: P.Play & Bool) -> Session:
  (p,dirty) = r
  Session{w,renderer,image,p,active,dirty,previous,last_frame}
def presented(renderer: R.Renderer, p: P.Play, +now: Nat, r: Window & Image & List<Event>) -> Session:
  (w,image,es) = r
  inputs(w,renderer,image,True{},now,now,Schedule.input(es,True{},(p,False{})))
def present(w: Window, p: P.Play, now: Nat, r: R.Renderer & Image) -> IO(Session):
  (renderer,image) = r
  do IO<Session>:
    result : Window & Image & List<Event> <- Window.frame(w,image)
    return presented(renderer,p,now,result)
def render(draw: Bool, session: Session) -> IO(Session):
  match draw:
    case False{}: IO.pure(Session,session)
    case True{}:
      Session{w,renderer,image,+p,_,_,now,_} = session
      present(w,p,now,R.frame(False{},p,renderer,image))
def advance(renderer: R.Renderer, image: Image, p: P.Play, +was_active: Bool, dirty: Bool, previous: Nat, last_frame: Nat,
  r: Window & Events.Activity & List<Event>) -> IO(Session):
  (w,+activity,es) = r
  do IO<Session>:
    +now : Nat <- Time.micros()
    +active : Bool = Schedule.active(activity)
    next : P.Play = Schedule.elapsed(active,was_active && Schedule.continuous(activity),(U32.to_f32(Time.elapsed(previous,now)) / 1000000.0 : F32),p)
    return inputs(w,renderer,image,active,now,last_frame,Schedule.input(es,active,(next,dirty || Bool.xor(active,was_active) || Bool.not(Schedule.continuous(activity)))))
def poll(session: Session) -> IO(Session):
  Session{w,renderer,image,+p,+active,+dirty,previous,+last_frame} = session
  do IO<Session>:
    now : Nat <- Time.micros()
    r : Window & Events.Activity & List<Event> <- Events.poll(w,Cadence.wait_ms(active,dirty,Schedule.period(p),Time.elapsed(last_frame,now)))
    advance(renderer,image,p,active,dirty,previous,last_frame,r)
def checked(session: Session) -> IO(Session):
  Session{w,renderer,image,+p,+active,+dirty,+previous,+last_frame} = session
  P.Play{_,_,_,_,_,_,_,_,quit,_,_,_,_,_,_,pace,hints} = p
  render(Bool.not(quit) && Cadence.due(active,dirty,Schedule.period(p),Time.elapsed(last_frame,previous)),
    Session{w,renderer,image,p,active,dirty,previous,last_frame})
def loop(n: Nat, session: Session) -> IO(Unit):
  match n:
    case 0n:
      Session{w,_,_,_,_,_,_,_} = session
      Window.close(w)
    case 1n+k:
      Session{w,renderer,image,+p,active,dirty,previous,last_frame} = session
      P.Play{_,_,_,_,_,_,_,_,quit,_,_,_,_,_,_,pace,hints} = p
      match quit:
        case True{}: Window.close(w)
        case False{}:
          do IO<Unit>:
            next : Session <- poll(Session{w,renderer,image,p,active,dirty,previous,last_frame})
            next : Session <- checked(next)
            loop(k,next)
def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("TURN - R rotate / Backspace or Delete restart / Tab chapters",760,760))
    w : Window <- Viewport.resolution(w,1024)
    +now : Nat <- Time.micros()
    loop(4294967295n,Session{w,R.create(),Pix{0},P.create(L.at(0)),True{},True{},now,now})
