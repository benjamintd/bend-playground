"""Resolution, retained buffers and actual backend through Scene.draw's API."""
import csv
from pathlib import Path

for backend, gpu in [('cpu', 0), ('metal', 1)]:
    rows = list(csv.reader(Path(f'build/scene-{backend}.csv').open()))
    cases = [(0, True), (0, False), (1, True), (1, False), (2, True), (0, False)]
    assert len(rows) == len(cases)
    for row, (level, visible) in zip(rows, cases):
        width = 512 << level
        edge = width // 2
        ink = edge * (edge + 1) // 2 if visible else 0
        assert list(map(int, row)) == [level, width * width, ink, 0, gpu, 17, 23], row
print('PASS: CPU/Metal scene resize, empty-after-filled frames, buffer reuse and actual backend reporting.')
