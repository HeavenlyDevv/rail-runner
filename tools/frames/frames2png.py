"""Convierte los dibujos de texto de tools/frames/*.txt en PNG (sprite + mascara) en assets/.
   ' ' = transparente, '#' = negro opaco, 0-F = pen de la paleta del juego."""
import sys, os
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import make_sprites as m
SYM = "0123456789ABCDEF"
for name in sys.argv[1:]:
    rows = [l.rstrip("\n").strip("|") for l in open(os.path.join(os.path.dirname(__file__), name + ".txt")) if l.strip()]
    spr = Image.new("RGBA", (14, 24), (0, 0, 0, 0)); msk = Image.new("RGB", (14, 24), (255, 255, 255))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == " ": continue
            pen = 0 if c == "#" else SYM.index(c)
            spr.putpixel((x, y), m.FW_RGB[m.PALETTE[pen]] + (255,))
            msk.putpixel((x, y), (0, 0, 0))
    spr.save(f"assets/minerov2_{name}.png"); msk.save(f"assets/minerov2_{name}_mask.png")
    print("assets/minerov2_%s.png (+ _mask)" % name)
