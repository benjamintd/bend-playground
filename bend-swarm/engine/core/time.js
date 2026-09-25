function micros_run() { return BigInt(Math.floor(performance.now() * 1000)); }
io_eff(CID(micros), micros_run);
