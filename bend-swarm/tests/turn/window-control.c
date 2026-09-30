#ifdef __OBJC__
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
static char test_focus_guard_key;
static void test_key(NSWindow* window, bool down) {
  NSEvent* key = [NSEvent keyEventWithType:down ? NSEventTypeKeyDown : NSEventTypeKeyUp
    location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber
    context:nil characters:@"d" charactersIgnoringModifiers:@"d" isARepeat:NO keyCode:2];
  [NSApp postEvent:key atStart:NO];
}
#endif
Term action_run(Env e, Term* f, IoWork* work) {
#ifdef __OBJC__
  NSWindow* window = (__bridge NSWindow*)(void*)(intptr_t)io_hand_v(f[0]);
  switch ((u32)f[1]) {
    case 0: {
      // An inert second window holds focus without relying on another app's
      // asynchronous activation. The measured game window stays visible.
      NSWindow* guard = [[NSWindow alloc] initWithContentRect:NSMakeRect(20,20,180,90)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
      guard.releasedWhenClosed = NO;
      guard.title = @"TURN focus guard";
      objc_setAssociatedObject(window,&test_focus_guard_key,guard,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      [guard makeKeyAndOrderFront:nil];
      break;
    }
    case 1: [NSApp hide:nil]; break;
    case 2: [window miniaturize:nil]; break;
    case 3:
      [(NSWindow*)objc_getAssociatedObject(window,&test_focus_guard_key) close];
      objc_setAssociatedObject(window,&test_focus_guard_key,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      [NSApp unhide:nil]; [window deminiaturize:nil];
      [window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES]; break;
    case 4: test_key(window,true); test_key(window,false); break;
    case 5: [window performClose:nil]; break;
    case 6:
      [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:NO block:^(NSTimer* timer) {
        test_key(window,true); test_key(window,false);
      }]; break;
  }
  if ((u32)f[1] <= 3) {
    // Exclude asynchronous AppKit activation/minimize transitions from timing.
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:0.3];
    while (deadline.timeIntervalSinceNow > 0) {
      NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:deadline
        inMode:NSDefaultRunLoopMode dequeue:YES];
      if (event != nil) [NSApp sendEvent:event];
    }
  }
#endif
  return f[0];
}
static void __attribute__((constructor)) action_use(void) {
  io_eff(CID(action),action_run,0);
}
