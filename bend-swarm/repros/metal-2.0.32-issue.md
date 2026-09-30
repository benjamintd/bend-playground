# Metal regression: a small parallel sum fails shader compilation on M2 Pro / macOS 15.7.4 in 2.0.32

## What happened

Bend 2.0.32 fails to build even the small parallel sum below on this Mac.
Clang produces the native executable, but its `--gpu-build` step fails:

```text
bend: Compiler encountered an internal error
Error: gpu-smoke failed to build gpu-smoke
```

macOS records an `MTLCompilerService` crash with `EXC_BAD_ACCESS`,
`SIGSEGV`, and `KERN_INVALID_ADDRESS at 0x0000000000000010`.
The faulting thread includes `llvm::MachineFunctionPass::runOnFunction`,
`llvm::FPPassManager::runOnFunction`, and `llvm::AGX::AGXCompilePlan::execute`.

The same source builds and runs on Metal using Bend 2.0.27 at
`95317d952c8fe5be18ef49f916b2a57250cfb0aa`, printing `134209536`.
That working revision was rebuilt and retested after the 2.0.32 failures.
The first failing commit between those versions has not been bisected.

## Reproduction

Save as `gpu-smoke.bend`:

```bend
import Base

def sum(+d: Nat, +i: U32) -> U32:
  match d:
    case 0n:
      i
    case 1n+p:
      a b = sum(p, i) sum(p, (i + U32.shln(1, p) : U32))
      (a + b : U32)

def main() -> IO(Unit):
  IO.print(U32.show(sum!(14n, 0)))
```

```sh
bend version
bend gpu-smoke.bend -o gpu-smoke
```

Expected: build succeeds; `./gpu-smoke --gpu on` prints `134209536`.
Observed: the build's GPU archive step fails with the error above. Running the
executable left by that failed build with `--gpu off --threads 10` prints the
correct `134209536`.

## Versions tested

- Official 2.0.32 darwin-arm64 binary: fails.
- Clean source checkout of tag `v2.0.32`, commit
  `573002f01ec6c52416d44489543f69a9625facf8`, invoked with Bun 1.2.13: same failure.
- 2.0.27 source at `95317d952c8fe5be18ef49f916b2a57250cfb0aa`: builds and runs on Metal.
- No local compiler/runtime patches. Tests ran with normal desktop Metal access.
- Official archive SHA-256 verified against the release:
  `d7debc002f59264f648dc94e45c2a9fab23e4b1ee0a390bf2acd8b1673e0cf55`.

## Environment

- MacBook Pro, Mac14,9; Apple M2 Pro, 10 CPU cores, 16 GPU cores, 16 GB RAM.
- macOS 15.7.4 (24G517); `uname -sm`: Darwin arm64.
- Apple clang version 17.0.0 (clang-1700.0.13.5).
- Command Line Tools compiler; no Homebrew clang override.

## Related issues / scope

I found no existing report matching this compilation crash when searching
issues for Metal, M1, M2, and the exact error on 2026-09-28.
[1139](https://github.com/bendlang/bend/issues/1139) reports a runtime slowdown
with shared Arrays; this example has no Arrays and fails before execution.
[1143](https://github.com/bendlang/bend/issues/1143) mentions earlier M1 pipeline
compilation sensitivity to atomic load forms. That may be relevant context,
but I have not established the cause of this M2 crash.

This blocks upgrading a working Metal application. Keeping the older project
pin is the current workaround. A compatibility fix or documented requirement
for a newer macOS/Metal compiler would help.
