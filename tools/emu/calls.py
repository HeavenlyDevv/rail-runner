"""Inclusive time per profiled function (from calls.csv), per game-loop iteration."""
import sys, collections, statistics
out = sys.argv[1]; loop_sym = sys.argv[2] if len(sys.argv) > 2 else "sys_render_frame"
d = collections.defaultdict(list)
for line in open(f"{out}/calls.csv"):
    n, t = line.strip().split(","); d[n].append(int(t) / 4)
loops = len(d.get(loop_sym, [])) or 1
print(f"{'function':26s} {'calls/loop':>10s} {'mean us':>8s} {'max us':>8s} {'ms/loop':>8s}")
for n, v in sorted(d.items(), key=lambda kv: -sum(kv[1])):
    print(f"{n:26s} {len(v)/loops:10.2f} {statistics.mean(v):8.0f} {max(v):8.0f} {sum(v)/loops/1000:8.2f}")
