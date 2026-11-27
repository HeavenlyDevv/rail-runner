"""Render miner frames (PNG paths or ASCII grid files) big, with a pixel grid and row/col numbers."""
import sys
from PIL import Image, ImageDraw
sys.path.insert(0, "/work/mine-fixed/tools")
import make_sprites as m
PW, PH = 22, 11                      # mode 0 pixel = 2:1
def load(path):
    if path.endswith(".png"):
        im = Image.open(path).convert("RGBA"); mk = Image.open(path.replace(".png", "_mask.png")).convert("RGB")
        g = []
        for y in range(im.size[1]):
            row = []
            for x in range(im.size[0]):
                p = im.getpixel((x, y)); opaque = mk.getpixel((x, y))[0] < 128
                row.append(None if not opaque else (0 if p[3] < 128 else m.pen_of(p)))
            g.append(row)
        return g
    sym = "0123456789ABCDEF"
    return [[None if c == " " else (0 if c == "#" else sym.index(c)) for c in line.rstrip("\n").strip("|")] for line in open(path) if line.strip()]
if __name__ == '__main__':
    frames = [(p.split("/")[-1], load(p)) for p in sys.argv[2:]]
    W = len(frames) * (14 * PW + 40) + 30; H = 24 * PH + 60
    img = Image.new("RGB", (W, H), (34, 36, 52)); d = ImageDraw.Draw(img)
    for k, (name, g) in enumerate(frames):
        ox, oy = 30 + k * (14 * PW + 40), 30
        d.text((ox, 8), name[:22], fill=(220, 220, 220))
        for y, row in enumerate(g):
            if k == 0: d.text((4, oy + y * PH), str(y), fill=(150, 150, 170))
            for x, v in enumerate(row):
                col = (60, 62, 84) if v is None else m.FW_RGB[m.PALETTE[v]]
                d.rectangle([ox + x * PW, oy + y * PH, ox + x * PW + PW - 1, oy + y * PH + PH - 1], fill=col, outline=(50, 50, 70))
    img.save(sys.argv[1])
