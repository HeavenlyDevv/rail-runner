"""Animated preview of miner frame sequences at game speed, 2:1 pixel aspect, over a rail strip."""
import sys
from PIL import Image
sys.path.insert(0, "/work/mine-fixed/tools"); sys.path.insert(0, "/work/rr/web")
import make_sprites as m
from gridview import load
S = 4
def to_img(g):
    im = Image.new("RGBA", (14 * 2 * S, 24 * S), (0, 0, 0, 0))
    for y, row in enumerate(g):
        for x, v in enumerate(row):
            if v is None: continue
            c = m.FW_RGB[m.PALETTE[v]]
            for dy in range(S):
                for dx in range(2 * S): im.putpixel((x * 2 * S + dx, y * S + dy), c + (255,))
    return im
F = {n: to_img(load(p)) for n, p in [a.split("=") for a in sys.argv[2:]]}
rail = Image.open("/work/mine-fixed/assets/railes_1.png").convert("RGB").resize((80 * S, 11 * S), Image.NEAREST)
seqs = {"run (old 3 frames)": ["r1"]*6 + ["r2"]*6 + ["r3"]*6,
        "run (new 6 frames)": ["r1","r1","r1","r1b","r1b","r1b","r2","r2","r2","r2b","r2b","r2b","r3","r3","r3","r3b","r3b","r3b"]}
frames = []
for t in range(18 * 4):
    W = Image.new("RGB", (len(seqs) * 140 * 2 // 2 + 40, 24 * S + 30), (0, 0, 0))
    for k, (title, seq) in enumerate(seqs.items()):
        ox = 20 + k * 140
        W.paste(rail.crop((0, 0, 120, 11 * S)), (ox, 13 * S + 10))
        spr = F[seq[t % len(seq)]]
        W.paste(spr, (ox + 4, 0 + 6), spr)
    frames.append(W)
frames[0].save(sys.argv[1], save_all=True, append_images=frames[1:], duration=20 * 3, loop=0)
sheet = Image.new("RGB", (len(F) * 14 * 2 * S + 20, 24 * S + 10), (30, 30, 46))
for k, (n, im) in enumerate(F.items()): sheet.paste(im, (10 + k * 14 * 2 * S, 5), im)
sheet.save(sys.argv[1].replace(".gif", "_sheet.png"))
