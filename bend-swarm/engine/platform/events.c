// Event/window metadata only. Rendering and simulation remain in Bend.
// The five-word event queue is the pinned Bend 2.0.27 Window adapter's ABI.
// Unlike Window.frame, this effect does not acquire a drawable or run Metal.
#ifdef __OBJC__
#import <AppKit/AppKit.h>

#import <objc/runtime.h>

// Keep notifications alive with the window, including between poll calls.
// This catches a resign/become-key pair occurring during presentation too.
@interface BendEngineActivity : NSObject
@property(nonatomic, weak) NSWindow* window;
@property(nonatomic) BOOL interrupted;
- (instancetype)initWithWindow:(NSWindow*)window;
@end
@implementation BendEngineActivity
- (instancetype)initWithWindow:(NSWindow*)window {
  self = [super init];
  if (self) {
    self.window = window;
    for (NSString* name in @[NSWindowDidBecomeKeyNotification,
        NSWindowDidResignKeyNotification, NSWindowDidChangeOcclusionStateNotification])
      [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:)
        name:name object:window];
    for (NSString* name in @[NSApplicationDidBecomeActiveNotification,
        NSApplicationDidResignActiveNotification, NSApplicationDidHideNotification,
        NSApplicationDidUnhideNotification])
      [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:)
        name:name object:NSApp];
  }
  return self;
}
- (void)changed:(NSNotification*)note {
  NSWindow* window = self.window;
  if (!NSApp.active || !window.keyWindow || !window.visible || window.miniaturized
      || !(window.occlusionState & NSWindowOcclusionStateVisible)) self.interrupted = YES;
  // Wake a sleeping poll on lifecycle changes, even without keyboard input.
  NSEvent* wake = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
    location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber
    context:nil subtype:0 data1:0 data2:0];
  [NSApp postEvent:wake atStart:NO];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
static char events_activity_key;

static Term events_pack(Env e, const u32* p, u64 count) {
  static const u32 cids[3] = { CID(Key), CID(Mouse), CID(Move) };
  Term list = term_pak(CID(Nil), 0);
  while (count > 0) {
    const u32* ev = p + 5 * --count;
    Term value;
    if (ev[0] == 3) {
      value = term_pak(CID(Close), 0);
    } else {
      u32 n = ev[0] == 1 ? 4 : 2;
      Loc at = heap_alloc(e, cls_fit(n));
      for (u32 j = 0; j < n; ++j) e.mem[at + j] = ev[j + 1];
      value = term_ctr(cids[ev[0]], at);
    }
    list = io_node(e, CID(Con), value, list);
  }
  return list;
}
#endif

Term native_run(Env e, Term* f, IoWork* work) {
#ifdef __OBJC__
  NSWindow* window = (__bridge NSWindow*)(void*)(intptr_t)io_hand_v(f[0]);
  @autoreleasepool {
    BendEngineActivity* activity = objc_getAssociatedObject(window,&events_activity_key);
    if (activity == nil) {
      activity = [[BendEngineActivity alloc] initWithWindow:window];
      objc_setAssociatedObject(window,&events_activity_key,activity,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSMutableData* events = [window.contentView valueForKey:@"evs"];
    // Already queued events (e.g. a close request) must not wait for another.
    NSDate* deadline = events.length || activity.interrupted ? NSDate.distantPast
      : [NSDate dateWithTimeIntervalSinceNow:(double)(u32)f[1] / 1000.0];
    for (;;) {
      NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny
        untilDate:deadline inMode:NSDefaultRunLoopMode dequeue:YES];
      if (event == nil) break;
      [NSApp sendEvent:event];
      deadline = NSDate.distantPast;
    }
    u32 bits = NSApp.active && window.keyWindow ? 1 : 0;
    if (window.visible && !window.miniaturized
        && (window.occlusionState & NSWindowOcclusionStateVisible)) bits |= 2;
    if (activity.interrupted) bits |= 4;
    activity.interrupted = NO;
    Term list = events_pack(e, events.bytes, events.length / 20);
    events.length = 0;
    return io_tup(e, f[0], io_tup(e, bits, list));
  }
#else
  // Do not pretend to support a lifecycle we cannot observe. The existing
  // Window.frame interface remains available on other native platforms.
  err_fail("Events.poll requires the macOS window adapter");
  return TERM_HOLE;
#endif
}
static void __attribute__((constructor)) native_use(void) {
  io_eff(CID(native), native_run, 0);
}
