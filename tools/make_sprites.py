"""Genera los datos de sprites del juego a partir de los PNG de assets/.

  * Minero y vagones: mascara y color intercalados (mascara, color, mascara, color...),
    el formato que consume sys/render.s:draw_masked en una sola pasada.
  * Railes: como el dibujo se repite cada 4 bytes, se guarda un patron de 4 bytes por fila
    y frame (repetido 4 veces = 16 bytes para poder copiar hasta 12 bytes desde cualquier fase).

Uso:  python3 tools/make_sprites.py [--check]   (desde la raiz del proyecto)
      --check compara la conversion con los .c generados por img2cpc (si existen).
"""
import re, sys, os
from PIL import Image

FW_RGB = {0:(0,0,0),1:(0,0,128),2:(0,0,255),3:(128,0,0),4:(128,0,128),5:(128,0,255),6:(255,0,0),
          7:(255,0,128),8:(255,0,255),9:(0,128,0),10:(0,128,128),11:(0,128,255),12:(128,128,0),
          13:(128,128,128),14:(128,128,255),15:(255,128,0),16:(255,128,128),17:(255,128,255),
          18:(0,255,0),19:(0,255,128),20:(0,255,255),21:(128,255,0),22:(128,255,128),
          23:(128,255,255),24:(255,255,0),25:(255,255,128),26:(255,255,255)}
PALETTE = [0,1,2,3,4,9,10,11,12,13,14,15,16,20,25,26]     # = cfg/image_conversion.mk

def pen_of(rgb):
    r, g, b = rgb[:3]
    return min(range(16), key=lambda p: sum((x - y) ** 2 for x, y in zip((r, g, b), FW_RGB[PALETTE[p]])))

def m0_byte(p0, p1):
    # modo 0: pixel izq. bits 7,3,5,1 / pixel der. bits 6,2,4,0 (bit0 del pen primero)
    b = 0
    for pen, bits in ((p0, (7, 3, 5, 1)), (p1, (6, 2, 4, 0))):
        for i, bit in enumerate(bits):
            if pen & (1 << i): b |= 1 << bit
    return b

def convert(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    rows = []
    for y in range(h):
        row = []
        for x in range(0, w, 2):
            a, b = im.getpixel((x, y)), im.getpixel((x + 1, y))
            pa = 0 if a[3] < 128 else pen_of(a)
            pb = 0 if b[3] < 128 else pen_of(b)
            row.append(m0_byte(pa, pb))
        rows.append(row)
    return rows

def flat(rows): return [b for r in rows for b in r]

def c_array(name):
    p = f"src/sprites/{name}.c"
    if not os.path.exists(p): return None
    body = open(p).read().split("{", 1)[1]          # solo el contenido del array
    return [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", body)]

# Minero: ciclo de carrera de 6 frames y poses de cambio de carril
MINER = [("m1", "minerov2_1"), ("m1b", "minerov2_run_1b"), ("m2", "minerov2_2"), ("m2b", "minerov2_run_2b"),
         ("m3", "minerov2_3"), ("m3b", "minerov2_run_3b"),
         ("crouch", "minerov2_crouch"), ("jump", "minerov2_jump"), ("duck", "minerov2_duck")]
CARTS = [f"trenv3_{t}_{i}" for t in ("tnt", "oro", "diamante", "gemas") for i in (1, 2, 3)]
RAILS = ["railes_1", "railes_2", "railes_3"]

def check():
    ok = True
    for name in [n for _, f in MINER[::2] for n in (f, f + "_mask")] + CARTS + ["trenv3_mascara"] + RAILS:
        mine, ref = flat(convert(f"assets/{name}.png")), c_array(name.replace("trenv3_mascara", "trenv3_mascara"))
        if ref is None: print(f"{name}: no .c to compare"); continue
        same = mine == ref
        ok &= same
        print(f"{name:22s} {'OK' if same else 'DIFF'} ({sum(a != b for a, b in zip(mine, ref))} bytes differ)")
    return ok

def interleave(sprite, mask, stats):
    out = []
    for s, m in zip(sprite, mask):
        if s & m: stats["fixed"] += 1        # color donde la mascara dice transparente
        out += [m, s & ~m & 0xFF]
    return out

def emit(f, label, data, comment=""):
    f.write(f"{label}::{('  ; ' + comment) if comment else ''}\n")
    for i in range(0, len(data), 16):
        f.write("  .db " + ", ".join(f"0x{b:02X}" for b in data[i:i + 16]) + "\n")

def generate():
    stats = {"fixed": 0}
    with open("src/sprites/masked_sprites.s", "w") as f:
        f.write(";; GENERADO por tools/make_sprites.py - no editar a mano\n")
        f.write(";; Formato: pares (mascara, color) por byte; mascara 1 = se ve el fondo\n\n")
        for label, png in MINER:
            emit(f, f"_spr_minero_{label}", interleave(flat(convert(f"assets/{png}.png")),
                                                       flat(convert(f"assets/{png}_mask.png")), stats), "7x24 bytes")
        cart_mask = flat(convert("assets/trenv3_mascara.png"))
        for name in CARTS:
            emit(f, f"_spr_{name}_m", interleave(flat(convert(f"assets/{name}.png")), cart_mask, stats), "11x16 bytes")
    with open("src/sprites/rails_data.s", "w") as f:
        f.write(";; GENERADO por tools/make_sprites.py - no editar a mano\n")
        f.write(";; Railes: 3 frames x 11 filas x 16 bytes (patron de 4 bytes repetido 4 veces)\n\n")
        f.write("rails_frames::\n")
        for fr, name in enumerate(RAILS):
            rows = convert(f"assets/{name}.png")
            for y, row in enumerate(rows):
                pat = row[:4]
                assert all(row[i] == pat[i % 4] for i in range(len(row))), f"{name} fila {y} no es periodica"
                f.write(f"  .db " + ", ".join(f"0x{b:02X}" for b in pat * 4) + f"   ; frame {fr} fila {y}\n")
    print(f"generated; {stats['fixed']} sprite bytes had colour under the transparent mask (cleared)")

if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    generate()
