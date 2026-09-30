// Runtime metadata, not simulation/render computation. Pinned Bend 2.0.27.
Term available_run(Env e, Term* f, IoWork* w) {
  return (Term)(io_gpu ? 1 : 0);
}
static void __attribute__((constructor)) available_use(void) {
  io_eff(CID(available), available_run, 0);
}
