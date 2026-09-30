#!/usr/bin/env python3
"""Bake the game's Latin Rubik outlines into plain Bend mesh geometry.

Offline only; the shipped game has no font parser or foreign renderer. This
small reader deliberately accepts only the simple TrueType glyphs used here.
Counter outlines are bridged and triangulated once, outside the frame loop.
"""
import argparse
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent
DATA = (ROOT / "Rubik-Bold.ttf").read_bytes()


def unpack(fmt, offset):
    return struct.unpack_from(">" + fmt, DATA, offset)


tables = {}
for i in range(unpack("H", 4)[0]):
    tag, _, offset, length = unpack("4sIII", 12 + i * 16)
    tables[tag.decode()] = offset


def cmap():
    start = tables["cmap"]
    for i in range(unpack("H", start + 2)[0]):
        platform, encoding, offset = unpack("HHI", start + 4 + i * 8)
        pos = start + offset
        if platform == 3 and encoding == 1 and unpack("H", pos)[0] == 4:
            count = unpack("H", pos + 6)[0] // 2
            ends = unpack("H" * count, pos + 14)
            starts = unpack("H" * count, pos + 16 + count * 2)
            deltas = unpack("h" * count, pos + 16 + count * 4)
            ranges = pos + 16 + count * 6
            result = {}
            for i, (lo, hi, delta) in enumerate(zip(starts, ends, deltas)):
                offset = unpack("H", ranges + 2 * i)[0]
                for code in range(lo, min(hi, 127) + 1):
                    glyph = unpack("H", ranges + 2 * i + offset + 2 * (code - lo))[0] if offset else code
                    result[code] = (glyph + delta) & 65535 if glyph else 0
            return result
    raise ValueError("Expected Windows Unicode BMP cmap")


def outline(glyph):
    long = unpack("h", tables["head"] + 50)[0]
    pos = tables["glyf"] + (unpack("I", tables["loca"] + glyph * 4)[0] if long else 2 * unpack("H", tables["loca"] + glyph * 2)[0])
    count, _, _, _, _ = unpack("hhhhh", pos)
    assert count >= 0, "The baked alphabet must use simple glyphs"
    ends = unpack("H" * count, pos + 10)
    pos += 10 + count * 2
    pos += 2 + unpack("H", pos)[0]
    flags = []
    while len(flags) <= ends[-1]:
        flag = DATA[pos]
        pos += 1
        repeat = DATA[pos] if flag & 8 else 0
        pos += bool(flag & 8)
        flags.extend([flag] * (repeat + 1))
    axes = []
    for short, same in [(2, 16), (4, 32)]:
        coords, value = [], 0
        for flag in flags:
            if flag & short:
                value += DATA[pos] * (1 if flag & same else -1)
                pos += 1
            elif not flag & same:
                value += unpack("h", pos)[0]
                pos += 2
            coords.append(value)
        axes.append(coords)
    contours, first = [], 0
    for end in ends:
        points = [(axes[0][i], axes[1][i], bool(flags[i] & 1)) for i in range(first, end + 1)]
        first = end + 1
        expanded = []
        for i, p in enumerate(points):
            expanded.append(p)
            q = points[(i + 1) % len(points)]
            if not p[2] and not q[2]:
                expanded.append(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, True))
        start = next(i for i, p in enumerate(expanded) if p[2])
        points = expanded[start:] + expanded[:start]
        points.append(points[0])
        poly, i = [points[0][:2]], 1
        while i < len(points):
            b = points[i]
            if b[2]:
                poly.append(b[:2])
                i += 1
            else:
                a, c = poly[-1], points[i + 1]
                # <= 3 font units from the true curve; < 0.3 px on the title.
                steps = max(1, math.ceil(math.sqrt(math.hypot(a[0] - 2*b[0] + c[0], a[1] - 2*b[1] + c[1]) / 12)))
                for j in range(1, steps + 1):
                    t = j / steps
                    poly.append(((1-t)**2*a[0] + 2*t*(1-t)*b[0] + t*t*c[0], (1-t)**2*a[1] + 2*t*(1-t)*b[1] + t*t*c[1]))
                i += 2
        contours.append([(round(x, 6), round(y, 6)) for x, y in poly])
    return contours


def cross(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])


def area(poly):
    return sum(a[0]*b[1]-b[0]*a[1] for a, b in zip(poly, poly[1:]+poly[:1])) / 2


def inside(p, poly):
    x, y = p
    return sum((a[1] > y) != (b[1] > y) and x < a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1])
               for a, b in zip(poly, poly[1:]+poly[:1])) % 2 == 1


def earclip(poly):
    result = []
    while len(poly) > 3:
        for i, b in enumerate(poly):
            a, c = poly[i-1], poly[(i+1) % len(poly)]
            if cross(a, b, c) <= 1e-7:
                continue
            if any(p not in (a,b,c) and min(cross(a,b,p),cross(b,c,p),cross(c,a,p)) >= -1e-7 for p in poly):
                continue
            result.append((a,b,c))
            poly = poly[:i] + poly[i+1:]
            break
        else:
            raise ValueError('No valid ear in font outline')
    result.append(tuple(poly))
    return result


def triangulate(contours):
    polys = [p[:-1] for p in contours]
    outers = [p for p in polys if sum(inside(p[0],q) for q in polys if q is not p) % 2 == 0]
    holes = [p for p in polys if p not in outers]
    result = []
    for outer in outers:
        poly = outer[:] if area(outer) > 0 else outer[::-1]
        members = [h for h in holes if inside(h[0],outer)]
        for hole in sorted(members, key=lambda h:max(x for x,y in h), reverse=True):
            hole = hole[:] if area(hole) < 0 else hole[::-1]
            hi = max(range(len(hole)), key=lambda i:hole[i][0])
            h = hole[hi]
            hits = []
            for i,a in enumerate(poly):
                b = poly[(i+1) % len(poly)]
                if (a[1]>h[1]) != (b[1]>h[1]):
                    x = a[0]+(h[1]-a[1])*(b[0]-a[0])/(b[1]-a[1])
                    if x >= h[0]: hits.append((x,i))
            x, i = min(hits)
            point = (x,h[1])
            if point == poly[i]:
                pass
            elif point == poly[(i+1)%len(poly)]:
                i = (i+1)%len(poly)
            else:
                poly.insert(i+1,point)
                i += 1
            poly = poly[:i+1] + hole[hi:] + hole[:hi+1] + [point] + poly[i+1:]
        result.extend(earclip(poly))
    expected = sum(abs(area(p)) for p in outers)-sum(abs(area(p)) for p in holes)
    assert abs(sum(abs(cross(*t))/2 for t in result)-expected) < 0.001, 'Triangulation must preserve area and counters'
    return result


def build():
    mapping = cmap()
    cap = max(y for poly in outline(mapping[ord("H")]) for _, y in poly)
    metrics_count = unpack("H", tables["hhea"] + 34)[0]
    chars = " !+,-./0123456789:<>?ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    advances, glyphs = {}, {}
    for c in chars:
        glyph = mapping[ord(c)]
        advances[c] = unpack("H", tables["hmtx"] + min(glyph, metrics_count-1)*4)[0] / cap * 7
        glyphs[c] = [] if c == " " else triangulate(outline(glyph))
    out = ['# Generated by assets/generate-font.py. Rubik-derived outline subset; see assets/OFL.txt.',
           '# Coordinates use a 7-unit cap height. No bitmap pixels or runtime font parsing.',
           'import Base', 'import ../../engine/render/mesh.bend as M', 'import ../../engine/render/batch.bend as B', '',
           'def vertex(+x: F32, +y: F32, +size: F32, u: F32, v: F32) -> M.Vertex:',
           '  M.Vertex{((x + u * size) * 2.0 : F32),((y + v * size) * 2.0 : F32),1.0,1.0}',
           'def face(+x: F32, +y: F32, +size: F32, color: U32, a: F32, b: F32, c: F32, d: F32, e: F32, f: F32, r: B.Batch) -> B.Batch:',
           '  B.push(M.Triangle{vertex(x,y,size,a,b),vertex(x,y,size,c,d),vertex(x,y,size,e,f),color},r)', '']
    for c, spans in glyphs.items():
        if not spans:
            continue
        out.extend([f'def glyph_{ord(c)}(+x: F32, +y: F32, +size: F32, +color: U32, r: B.Batch) -> B.Batch:'])
        for tri in spans:
            coords = [v for x,y in tri for v in (x/cap*7,(cap-y)/cap*7)]
            values = ','.join(f'F32.neg({abs(v):.5f})' if v < 0 else f'{v:.5f}' for v in coords)
            out.append(f'  r = face(x,y,size,color,{values},r)')
        out.extend(['  r', ''])
    out.extend(['def advance(code: U32) -> F32:', '  match code:'])
    out.extend(f'    case {ord(c)}: {(advances[c] + 0.48):.5f}' for c in chars)
    out.extend(['    case _: 6.0', '',
                'def glyph(code: U32, x: F32, y: F32, size: F32, color: U32, r: B.Batch) -> B.Batch:', '  match code:'])
    out.extend(f'    case {ord(c)}: glyph_{ord(c)}(x,y,size,color,r)' for c in chars if c != ' ')
    out.extend(['    case 32: r', '    case _: glyph_63(x,y,size,color,r)', '',
                'def measure(s: String, +size: F32) -> F32:', '  match s:',
                '    case SNil{}: 0.0',
                '    case SCon{Chr{code},rest}: (advance(code) * size + measure(rest,size) : F32)', '',
                'def text(s: String, +x: F32, +y: F32, +size: F32, +color: U32, r: B.Batch) -> B.Batch:',
                '  match s:', '    case SNil{}: r',
                '    case SCon{Chr{+code},rest}: text(rest,(x + advance(code) * size : F32),y,size,color,glyph(code,x,y,size,color,r))', ''])
    print(f'{len(chars)} glyphs, {sum(len(v) for v in glyphs.values())} triangles, largest {max(len(v) for v in glyphs.values())}')
    return '\n'.join(out)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    target = ROOT.parent / 'font.bend'
    generated = build()
    if args.check:
        assert target.read_text() == generated, 'Stale font.bend; rerun generate-font.py'
    else:
        target.write_text(generated)
