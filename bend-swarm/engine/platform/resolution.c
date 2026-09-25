// Host presentation metadata only; uses Bend's existing Window presentation.
Term resolution_run(Env e, Term* f, IoWork* work) {
#ifdef __OBJC__
  NSWindow* window = (__bridge NSWindow*)(void*)(intptr_t)io_hand_v(f[0]);
  CAMetalLayer* layer = (CAMetalLayer*)window.contentView.layer;
  u32 size = (u32)f[1];
  if (layer.drawableSize.width != size || layer.drawableSize.height != size) {
    layer.drawableSize = CGSizeMake(size, size);
  }
#endif
  return f[0];
}
static void __attribute__((constructor)) resolution_use(void) {
  io_eff(CID(resolution), resolution_run, 0);
}
