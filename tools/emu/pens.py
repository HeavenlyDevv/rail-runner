import re, glob, collections, sys
root = sys.argv[1]
def pens(b):
    p0 = ((b>>7)&1)|(((b>>3)&1)<<1)|(((b>>5)&1)<<2)|(((b>>1)&1)<<3)
    p1 = ((b>>6)&1)|(((b>>2)&1)<<1)|(((b>>4)&1)<<2)|(((b>>0)&1)<<3)
    return p0, p1
tot = collections.Counter(); where = collections.defaultdict(collections.Counter)
for f in sorted(glob.glob(root + "/src/sprites/*.c")):
    name = f.split("/")[-1][:-2]
    if "palette" in name or "mask" in name or "mascara" in name: continue
    data = [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", open(f).read())]
    for b in data:
        for p in pens(b): tot[p] += 1; where[p][name] += 1
fw = [0,1,2,3,4,9,10,11,12,13,14,15,16,20,25,26]
for p in range(16):
    top = ", ".join(f"{n}:{c}" for n, c in where[p].most_common(5))
    print(f"pen {p:2d} fw {fw[p]:2d}: {tot[p]:6d} px in {len(where[p]):2d} sprites  {top}")
