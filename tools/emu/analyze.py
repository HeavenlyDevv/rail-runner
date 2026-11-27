"""Summarise rrsim output: per-system CPU time per game-loop iteration, fps, game state."""
import sys, csv, collections, statistics

TICKS_PER_US = 4          # chips runs the CPC at 4 MHz
FRAME_US = 19968

def load_trace(path):
    rows = []
    with open(path) as f:
        for line in f:
            t, name = line.strip().split(",")
            rows.append((int(t), name))
    return rows

def loop_stats(rows, loop_start, order, wait_sym):
    """Split the trace into iterations beginning at loop_start; time each system."""
    iters, cur = [], None
    for t, name in rows:
        if name == loop_start:
            if cur: iters.append(cur)
            cur = [(t, name)]
        elif cur is not None and name in order:
            cur.append((t, name))
    per_sys = collections.defaultdict(list)
    periods, busy = [], []
    for a, b in zip(iters, iters[1:]):
        seq = a + [b[0]]
        period = (b[0][0] - a[0][0]) / TICKS_PER_US
        periods.append(period)
        wait = 0
        for (t0, n0), (t1, _) in zip(seq, seq[1:]):
            d = (t1 - t0) / TICKS_PER_US
            per_sys[n0].append(d)
            if n0 == wait_sym: wait += d
        busy.append(period - wait)
    return periods, busy, per_sys

def main():
    out = sys.argv[1]
    order = sys.argv[2].split(",")
    wait_sym = sys.argv[3] if len(sys.argv) > 3 else "cpct_waitVSYNC_asm"
    rows = load_trace(f"{out}/trace.csv")
    periods, busy, per_sys = loop_stats(rows, order[0], set(order), wait_sym)
    if not periods:
        print("no game-loop iterations found"); return
    frames = [round(p / FRAME_US) for p in periods]
    print(f"iterations: {len(periods)}")
    print(f"loop period  mean {statistics.mean(periods)/1000:6.1f} ms  max {max(periods)/1000:6.1f} ms"
          f"  -> {1e6/statistics.mean(periods):5.1f} updates/s")
    print(f"busy (CPU)   mean {statistics.mean(busy)/1000:6.1f} ms  max {max(busy)/1000:6.1f} ms  (budget 20.0 ms)")
    hist = collections.Counter(frames)
    print("frames per update:", ", ".join(f"{k}f x{v}" for k, v in sorted(hist.items())))
    print(f"{'system':28s} {'mean ms':>8s} {'max ms':>8s}")
    for n in order:
        if per_sys[n]:
            print(f"{n:28s} {statistics.mean(per_sys[n])/1000:8.2f} {max(per_sys[n])/1000:8.2f}")

if __name__ == "__main__":
    main()
