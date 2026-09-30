import Base
import ../../engine/platform/events.bend as Events
import ../../engine/core/time.bend as Time
import ./window-control.bend as Host

def event_text(e: Event) -> String:
  match e:
    case Key{code,down}: " key:" ++ U32.show(code) ++ ":" ++ U32.show(Bool.to_u32(down))
    case Close{}: " close"
    case _: " pointer"
def event_list(es: List<Event>) -> String:
  match es:
    case Nil{}: ""
    case e <> rest: event_text(e) ++ event_list(rest)
def observed(name: String, start: Nat, r: Window & Events.Activity & List<Event>) -> IO(Window):
  (w,Events.Activity{focus,visible,interrupted},es) = r
  do IO<Window>:
    end : Nat <- Time.micros()
    Unit <- IO.print(name ++ "," ++ U32.show(Bool.to_u32(focus)) ++ "," ++ U32.show(Bool.to_u32(visible))
      ++ "," ++ U32.show(Bool.to_u32(interrupted)) ++ "," ++ U32.show(Time.elapsed(start,end)) ++ "," ++ event_list(es))
    return w
def probe(name: String, timeout: U32, w: Window) -> IO(Window):
  do IO<Window>:
    start : Nat <- Time.micros()
    r : Window & Events.Activity & List<Event> <- Events.poll(w,timeout)
    observed(name,start,r)
def only_keys(es: List<Event>) -> List<Event>:
  match es:
    case Nil{}: Nil{}
    case Key{100,down} <> rest: Key{100,down} <> only_keys(rest)
    case _ <> rest: only_keys(rest)
def keyed(r: Window & Events.Activity & List<Event>) -> Window & Events.Activity & List<Event>:
  (w,activity,es) = r
  (w,activity,only_keys(es))
def seek(n: Nat, +start: Nat, r: Window & Events.Activity & List<Event>) -> IO(Window):
  match n:
    case 0n: observed("early-wake",start,r)
    case 1n+k:
      (w,activity,es) = r
      match es:
        case Nil{}:
          do IO<Window>:
            next : Window & Events.Activity & List<Event> <- Events.poll(w,1000)
            seek(k,start,keyed(next))
        case e <> rest: observed("early-wake",start,(w,activity,e <> rest))
def early(w: Window) -> IO(Window):
  do IO<Window>:
    +start : Nat <- Time.micros()
    r : Window & Events.Activity & List<Event> <- Events.poll(w,1000)
    seek(20n,start,keyed(r))
def opened(w: Window) -> IO(Unit):
  do IO<Unit>:
    w : Window <- Host.action(w,3)
    w : Window <- probe("ready",0,w)
    w : Window <- Host.action(w,4)
    w : Window <- probe("keys",0,w)
    w : Window <- probe("drained",0,w)
    w : Window <- Host.action(w,6)
    w : Window <- early(w)
    w : Window <- Host.action(w,0)
    w : Window <- probe("background",50,w)
    w : Window <- Host.action(w,3)
    w : Window <- probe("resumed",0,w)
    w : Window <- Host.action(w,0)
    w : Window <- Host.action(w,3)
    w : Window <- probe("interrupted",1000,w)
    w : Window <- Host.action(w,5)
    w : Window <- probe("close",1000,w)
    Window.close(w)
def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("TURN event adapter test",320,240))
    opened(w)
