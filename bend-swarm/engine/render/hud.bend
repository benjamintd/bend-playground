import Base
import ../core/math.bend as M

# Tiny host-side bitmap HUD. Glyphs are packed scalars; no scene data or lists
# are accessed per pixel. This is Bend rasterization, not a host text effect.
def glyph_code(+c: U32) -> U32:
  M.word(U32.is_eq(c,48),31599,
  M.word(U32.is_eq(c,49),29850,
  M.word(U32.is_eq(c,50),29671,
  M.word(U32.is_eq(c,51),31207,
  M.word(U32.is_eq(c,52),18925,
  M.word(U32.is_eq(c,53),31183,
  M.word(U32.is_eq(c,54),31695,
  M.word(U32.is_eq(c,55),9383,
  M.word(U32.is_eq(c,56),31727,
  M.word(U32.is_eq(c,57),31215,
  M.word(U32.is_eq(c,65),23530,
  M.word(U32.is_eq(c,66),15083,
  M.word(U32.is_eq(c,67),29263,
  M.word(U32.is_eq(c,68),15211,
  M.word(U32.is_eq(c,69),29391,
  M.word(U32.is_eq(c,70),4815,
  M.word(U32.is_eq(c,71),31567,
  M.word(U32.is_eq(c,72),23533,
  M.word(U32.is_eq(c,73),29847,
  M.word(U32.is_eq(c,74),31524,
  M.word(U32.is_eq(c,75),23277,
  M.word(U32.is_eq(c,76),29257,
  M.word(U32.is_eq(c,77),23549,
  M.word(U32.is_eq(c,78),24573,
  M.word(U32.is_eq(c,79),31599,
  M.word(U32.is_eq(c,80),5103,
  M.word(U32.is_eq(c,81),20335,
  M.word(U32.is_eq(c,82),23275,
  M.word(U32.is_eq(c,83),31183,
  M.word(U32.is_eq(c,84),9367,
  M.word(U32.is_eq(c,85),31597,
  M.word(U32.is_eq(c,86),11117,
  M.word(U32.is_eq(c,87),24557,
  M.word(U32.is_eq(c,88),23213,
  M.word(U32.is_eq(c,89),9389,
  M.word(U32.is_eq(c,90),29351,
  M.word(U32.is_eq(c,46),8192,
  M.word(U32.is_eq(c,47),4772,
  M.word(U32.is_eq(c,45),448,
    0)))))))))))))))))))))))))))))))))))))))

def morton(+x: U32, +y: U32) -> U32:
  (U32.and(x,1) + U32.shln(U32.and(y,1),1n)
    + U32.shln(U32.and(x,2),1n) + U32.shln(U32.and(y,2),2n)
    + U32.shln(U32.and(x,4),2n) + U32.shln(U32.and(y,4),3n)
    + U32.shln(U32.and(x,8),3n) + U32.shln(U32.and(y,8),4n) : U32)

def text(s: String, +x: U32, +y: U32, a: Array<U32>) -> Array<U32>:
  match s:
    case SNil{}: a
    case SCon{Chr{+c},rest}:
      +nl = U32.is_eq(c,10)
      text(rest,M.word(nl,0,(x + 1 : U32)),M.word(nl,(y + 1 : U32),y),
        Array.set(U32,a,morton(x,y),glyph_code(c)))

def ink(+x: U32, +y: U32, code: U32) -> U32:
  M.word(((x < 3) && (y < 5) : U32) && U32.is_ne(U32.and(U32.shrn(code,
    U32.to_nat((y * 3 + x : U32))),1),0),12508141,660510)

def glyph(+d: Nat, +x: U32, +y: U32, +code: U32) -> Image:
  match d:
    case 0n: Pix{ink(x,y,code)}
    case 1n+p:
      +h = U32.shln(1,p)
      Qua{glyph(p,x,y,code),glyph(p,(x + h : U32),y,code),
        glyph(p,x,(y + h : U32),code),glyph(p,(x + h : U32),(y + h : U32),code)}

def letter(+code: U32) -> Image:
  Qua{glyph(2n,0,0,code),Pix{660510},glyph(2n,0,4,code),Pix{660510}}

def letters(a: Array<U32>) -> Image:
  match a:
    case ALeaf{c}: letter(c)
    case ANode{ANode{a,b},ANode{c,d}}:
      Qua{letters(a),letters(b),letters(c),letters(d)}
    case _: Pix{660510}

def panel(s: String) -> Image:
  letters(text(s,0,0,Array.new(U32,8n,0)))

def corner(hud: Image, img: Image) -> Image:
  match img:
    case Qua{_,tr,bl,br}: Qua{hud,tr,bl,br}
    case Pix{+c}: Qua{hud,Pix{c},Pix{c},Pix{c}}

def overlay(hud: Image, img: Image) -> Image:
  match img:
    case Qua{tl,tr,bl,br}: Qua{corner(hud,tl),tr,bl,br}
    case Pix{+c}: Qua{corner(hud,Pix{c}),Pix{c},Pix{c},Pix{c}}
