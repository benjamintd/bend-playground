# Bend Swarm

When editing this project:

1. Read `bend guide` using the pinned `scripts/bend` launcher.
2. Read `bend guide shaders`.
3. Inspect the current relevant Base definitions instead of guessing APIs.
4. Run correctness tests after every structural change.
5. Run `scripts/bend PROOF.bend` whenever code covered by laws changes.
6. Do not introduce per-agent heap allocations in frame loops.
7. Do not introduce shared +Data into an inner GPU loop without benchmarking it.
8. Keep unsafe array sharing isolated in documented, tested primitives.
9. Do not use foreign C/Metal/CUDA code for simulation or rendering computation.
10. Benchmark before and after every performance-oriented architectural change.
11. Prefer simpler data layouts over abstraction layers.
12. Never claim a performance improvement without numbers.

Do Phase 0 first. Do not start the full engine until GPU compilation works.
Preserve existing benchmark findings. Keep small runtime/compiler reproductions
under repros/; do not patch Bend itself. Distinguish measured results from goals.
