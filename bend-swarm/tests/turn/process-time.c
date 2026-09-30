#include <sys/resource.h>
Term cpu_micros_run(Env e, Term* f, IoWork* work) {
  struct rusage usage;
  getrusage(RUSAGE_SELF,&usage);
  return (Term)((u64)usage.ru_utime.tv_sec * 1000000 + usage.ru_utime.tv_usec
    + (u64)usage.ru_stime.tv_sec * 1000000 + usage.ru_stime.tv_usec);
}
static void __attribute__((constructor)) cpu_micros_use(void) {
  io_eff(CID(cpu_micros),cpu_micros_run,0);
}
