// Query logical content dimensions rather than assuming the requested size.
// macOS may constrain a window to the available screen. No rendering or
// simulation computation belongs in this host-only effect.
Term dimensions_run(Env e, Term* f, IoWork* work) {
  u32 width = 1024, height = 1024;
#ifdef __OBJC__
  NSWindow* window = (__bridge NSWindow*)(void*)(intptr_t)io_hand_v(f[0]);
  NSSize size = window.contentView.bounds.size;
  width = (u32)fmax(1, size.width);
  height = (u32)fmax(1, size.height);
#elif defined(__linux__)
  BendWin* window = (BendWin*)(intptr_t)io_hand_v(f[0]);
  XWindowAttributes attr;
  XGetWindowAttributes(window->dpy, window->win, &attr);
  width = attr.width;
  height = attr.height;
#endif
  return io_tup(e, f[0], io_tup(e, width, height));
}
static void __attribute__((constructor)) dimensions_use(void) {
  io_eff(CID(dimensions), dimensions_run, 0);
}
