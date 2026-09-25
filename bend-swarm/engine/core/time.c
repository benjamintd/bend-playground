Term micros_run(Env e, Term* f, IoWork* w) {
  return (Term)(io_tick() / 1000);
}
static void __attribute__((constructor)) micros_use(void) {
  io_eff(CID(micros), micros_run, 0);
}
