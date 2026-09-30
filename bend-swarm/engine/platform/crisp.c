Term enable_run(Env e, Term* f, IoWork* work) {
#ifdef __OBJC__
  NSWindow* window = (__bridge NSWindow*)(void*)(intptr_t)io_hand_v(f[0]);
  window.contentView.layer.magnificationFilter = kCAFilterNearest;
  window.contentView.layer.minificationFilter = kCAFilterNearest;
#endif
  return f[0];
}
static void __attribute__((constructor)) enable_use(void) {
  io_eff(CID(enable), enable_run, 0);
}
