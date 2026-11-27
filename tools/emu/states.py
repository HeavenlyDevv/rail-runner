"""Print game-state transitions from watch.csv (only when something changes)."""
import sys
keys = sys.argv[2].split(",") if len(sys.argv) > 2 else None
prev = None
for line in open(sys.argv[1] + "/watch.csv"):
    parts = line.strip().split(",")
    fr = int(parts[0]); d = dict(p.split("=") for p in parts[1:])
    shown = {k: v for k, v in d.items() if (keys is None or k in keys)}
    if shown != prev:
        print(f"f{fr:5d} " + " ".join(f"{k}={v}" for k, v in shown.items()))
        prev = shown
