import csv
from pathlib import Path

for backend, available in [("cpu", "0"), ("gpu", "1")]:
    rows = list(csv.reader(Path(f"build/policy-{backend}.csv").open()))
    assert rows.pop(0) == ["available", available]
    assert len(rows) == 34
    seen = set()
    for row in rows:
        level, mode, effect, count, tree_errors, differences, max_channel = map(int, row)
        seen.add((level, mode, effect))
        assert count == (512 << level) ** 2
        assert tree_errors == 0, row
        # CPU vs Metal transcendental math may round one channel differently.
        assert max_channel <= (1 if effect & 2 else 0), row
        if max_channel == 0:
            assert differences == 0
    assert seen == {(0, mode, effect) for mode in range(8) for effect in range(4)} | {(1, 1, 3), (2, 6, 3)}
print("PASS: all 8 bin/raster/post policies × 4 effect modes, CPU fallback, repeated Image reuse and 512/1024/2048 presentation trees.")
