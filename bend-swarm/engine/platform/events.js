// Bend's JS Window adapter is headless (no input or native lifecycle).
function native_run(window, timeout_ms) {
  return {fst:window,snd:{fst:3,snd:{$:CID(Nil)}}};
}
io_eff(CID(native),native_run);
