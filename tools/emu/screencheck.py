"""Oracle: rebuild the VISIBLE buffer from the entity state in RAM and compare with video memory.

For the buffer on screen, each entity records what it drew there (slot here_*/there_*).
Expected image = black + rails (frame that buffer has per band)
                 + carts  : (rails AND mask) OR colour
                 + lamps  : colour (opaque)
                 + miner  : (screen AND mask) OR colour, drawn last
Only the play area (lines 0..137) is checked.
"""
import sys, re, glob
mapf, files = sys.argv[1], sys.argv[2:]
syms = {}
for l in open(mapf):
    m = re.match(r"\s+0000([0-9A-F]{4})\s+(\S+)", l)
    if m: syms[m.group(2)] = int(m.group(1), 16)
E, ES = syms["e_array"], 25
RAIL_Y = (40, 80, 120); RAIL_H = 11
def addr(base, x, y): return base + (y % 8) * 0x800 + (y // 8) * 80 + x
bad_total = 0
for f in files:
    ram = open(f, "rb").read()
    back = ram[syms["start_mem"] + 1] << 8          # buffer to be drawn next
    vis = 0xC000 if back == 0x8000 else 0x8000
    slot = 0 if vis == 0x8000 else 4
    bf = ram[syms["band_frames"] + (0 if vis == 0x8000 else 3): syms["band_frames"] + (0 if vis == 0x8000 else 3) + 3]
    frames = syms["rails_frames"]
    exp = {}
    for y in range(138):
        for x in range(80):
            v = 0
            for k, T in enumerate(RAIL_Y):
                if T <= y < T + RAIL_H:
                    v = ram[frames + bf[k] * 176 + (y - T) * 16 + (x & 3)]
            exp[(x, y)] = v
    ents = []
    for i in range(14):
        e = ram[E + i * ES: E + i * ES + ES]
        if e[0] == 0: break
        hx, hy = e[16 + slot], e[17 + slot]
        hs = e[18 + slot] | e[19 + slot] << 8
        if hy == 0xFF: continue
        ents.append(dict(i=i, type=e[0], w=e[5], h=e[6], flags=e[15], x=hx, y=hy, spr=hs))
    order = [d for d in ents if not d["type"] & 0x04] + [d for d in ents if d["type"] & 0x04]
    for d in order:
        masked, bg = d["flags"] & 0x01, d["flags"] & 0x80
        p = d["spr"]
        for yy in range(d["h"]):
            for xx in range(d["w"]):
                X, Y = d["x"] + xx, d["y"] + yy
                if masked:
                    m, c = ram[p], ram[p + 1]; p += 2
                    under = exp.get((X, Y), 0)
                    if bg:   # rails/black under, not the screen
                        under = 0
                        for k, T in enumerate(RAIL_Y):
                            if T <= Y < T + RAIL_H: under = ram[frames + bf[k] * 176 + (Y - T) * 16 + (X & 3)]
                    v = (under & m) | c
                else:
                    v = ram[p]; p += 1
                if Y < 138: exp[(X, Y)] = v
    bad = [(x, y) for (x, y), v in exp.items() if ram[addr(vis, x, y)] != v]
    bad_total += len(bad)
    status = "OK" if not bad else f"{len(bad)} bytes differ, e.g. {bad[:6]}"
    print(f"{f.split('/')[-1]}: visible={vis:04X} entities={len(ents)} {status}")
sys.exit(1 if bad_total else 0)
