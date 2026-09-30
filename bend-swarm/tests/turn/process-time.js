function cpu_micros_run() { const t=process.cpuUsage(); return BigInt(t.user+t.system); }
io_eff(CID(cpu_micros),cpu_micros_run);
