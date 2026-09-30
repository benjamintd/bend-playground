#!/usr/bin/env python3
"""Native camera/demo regression images; run after scripts/build-camera."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
records = []

def framebuffer(path):
    with path.open() as f:
        assert f.readline().strip() == 'P3'
        w, h = map(int, f.readline().split())
        assert f.readline().strip() == '255'
        pixels = bytearray()
        for line in f:
            pixels.extend(map(int, line.split()))
    assert len(pixels) == w*h*3
    return w, h, pixels

cases = [('mono', 'perspective', 512, 80), ('mono', 'ortho', 512, 80),
         ('voxel', 'perspective', 512, 0), ('voxel', 'ortho', 512, 0),
         ('mono', 'perspective', 2048, 80), ('voxel', 'ortho', 1024, 0)]
for scene, projection, size, tick in cases:
    outputs = []
    for backend, gpu in [('cpu', 'off'), ('metal', 'on')]:
        target = root / f'build/camera-{scene}-{projection}-{size}-{backend}.ppm'
        with target.open('w') as stream:
            subprocess.run([str(root/'build/camera'), '--gpu', gpu, '--threads', '10', '--',
                            'snapshot', scene, projection, str(size), '0', str(tick)],
                           cwd=root, stdout=stream, check=True, timeout=300)
        w, h, pixels = framebuffer(target)
        assert (w, h) == (size, size)
        if scene == 'mono':
            assert set(pixels) == {0, 255}, 'strict monochrome channels'
            assert all(pixels[i] == pixels[i+1] == pixels[i+2] for i in range(0,len(pixels),3))
            black = pixels[::3].count(0)
            assert size*size*.03 < black < size*size*.75, 'scene has visible geometry and background'
        else:
            assert len(set(bytes(pixels[i:i+3]) for i in range(0,len(pixels),3))) >= 4
        outputs.append(pixels)
        records.append({'scene':scene,'projection':projection,'size':size,'backend':backend,
                        'pixels':size*size,'sha256':hashlib.sha256(pixels).hexdigest()})
        print('PASS',scene,projection,size,backend,flush=True)
    differences = sum(outputs[0][i:i+3] != outputs[1][i:i+3] for i in range(0,len(outputs[0]),3))
    # CPU and Metal may resolve a subpixel boundary differently due to F32 math.
    assert differences <= size*size*.001, (scene,projection,size,differences)
    records[-1]['cpu_metal_pixel_differences'] = differences
(root/'results/camera-native-validation.json').write_text(json.dumps(records,indent=2)+'\n')
