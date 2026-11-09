#!/usr/bin/env python3
"""Build 3 README charts straight from the SQL query files (psql --csv), so charts can never drift from the queries.
Colours: validated categorical slots 1-2 (blue, orange) + a single-hue sequential blue for the heatmap."""
import io, pathlib, subprocess
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import numpy as np
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs"; OUT.mkdir(exist_ok=True)
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e6e5e1"
BLUE, ORANGE = "#2a78d6", "#eb6834"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.edgecolor": GRID, "axes.labelcolor": INK2,
                     "xtick.color": INK2, "ytick.color": INK2, "figure.facecolor": SURFACE, "axes.facecolor": SURFACE})


def q(name):
    r = subprocess.run(["psql", "-X", "-q", "--csv", "-v", "ON_ERROR_STOP=1", "-f", str(ROOT / "03_analysis" / name)],
                       capture_output=True, text=True)
    if r.returncode: raise SystemExit(r.stderr)
    return pd.read_csv(io.StringIO(r.stdout))


def clean(ax):
    for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
    ax.tick_params(length=0); ax.yaxis.grid(True, color=GRID, lw=0.8); ax.set_axisbelow(True)


# 1 -- cohort retention heatmap (sequential, one hue, light -> dark)
d = q("q03_cohort_retention.sql").set_index("cohort_month")
m = d[[f"m{i}_pct" for i in range(1, 7)]]
cmap = LinearSegmentedColormap.from_list("seq", ["#e8f0fb", BLUE, "#0f3d7a"])
fig, ax = plt.subplots(figsize=(8.2, 5.4))
ax.imshow(np.ma.masked_invalid(m.values), cmap=cmap, aspect="auto", vmin=0, vmax=65)
for i in range(m.shape[0]):
    for j in range(m.shape[1]):
        v = m.values[i, j]
        if not np.isnan(v):
            ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=9, color="white" if v > 28 else INK)
ax.set_xticks(range(6), [f"Month +{i}" for i in range(1, 7)])
ax.set_yticks(range(len(m)), [f"{c[:7]}  (n={n:,})" for c, n in zip(m.index, d.cohort_size)], fontsize=9)
ax.xaxis.tick_top(); ax.tick_params(length=0)
for s in ax.spines.values(): s.set_visible(False)
ax.set_title("Share of each first-order cohort that orders again in month +n (%)\nBlank = month not yet observed",
             loc="left", color=INK, fontsize=11, pad=34)
fig.tight_layout(); fig.savefig(OUT / "chart_cohort_retention.png", dpi=160); plt.close(fig)

# 2 -- reorder within 30 days by first-delivery time, and by first-order coupon
a = q("q08_slow_first_delivery_vs_reorder.sql")
b = q("q08b_first_order_coupon_vs_reorder.sql")
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(9.6, 4.3), gridspec_kw={"width_ratios": [3, 2]})
la = [f"{t.split(maxsplit=1)[1]}\n(n={n:,})" for t, n in zip(a.first_order_delivery_time, a.customers)]
bars = ax1.bar(la, a.reorder_30d_pct, color=BLUE, width=0.55)
for r, v in zip(bars, a.reorder_30d_pct):
    ax1.text(r.get_x() + r.get_width() / 2, v + 1, f"{v:.1f}%", ha="center", color=INK, fontsize=10, fontweight="bold")
ax1.set_ylim(0, 100); ax1.set_title("By delivery time of the first order", loc="left", color=INK, fontsize=10); clean(ax1)
ax1.set_ylabel("Ordered again within 30 days (%)")
lb = [f"{t}\n(n={n:,})" for t, n in zip(b.first_order.str.replace("Used a first-order coupon", "Used coupon"), b.customers)]
bars = ax2.bar(lb, b.reorder_30d_pct, color=[ORANGE if "coupon" in t else BLUE for t in b.first_order], width=0.5)
for r, v in zip(bars, b.reorder_30d_pct):
    ax2.text(r.get_x() + r.get_width() / 2, v + 1, f"{v:.1f}%", ha="center", color=INK, fontsize=10, fontweight="bold")
ax2.set_ylim(0, 100); ax2.set_title("By first-order coupon", loc="left", color=INK, fontsize=10); clean(ax2)
fig.suptitle("Slow first deliveries and coupon-led signups reorder less (synthetic data)", x=0.01, ha="left", color=INK, fontsize=11)
fig.tight_layout(rect=(0, 0, 1, 0.95)); fig.savefig(OUT / "chart_reorder_rates.png", dpi=160); plt.close(fig)

# 3 -- demand and speed by hour (two stacked panels, one axis each; no dual axis)
h = q("q02_hourly_demand_and_speed.sql")
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8.6, 5.6), sharex=True, gridspec_kw={"height_ratios": [3, 2]})
ax1.bar(h.hour, h.orders, color=BLUE, width=0.7)
ax1.set_ylabel("Delivered orders"); ax1.set_title("Evening and morning peaks: demand rises and the 'on time' share falls",
                                                  loc="left", color=INK, fontsize=11); clean(ax1)
ax2.plot(h.hour, h.sla_met_pct, color=ORANGE, lw=2, marker="o", ms=5)
ax2.set_ylabel("Delivered within\npromised time (%)"); ax2.set_ylim(40, 90); ax2.set_xlabel("Hour of day (IST)")
ax2.set_xticks(range(0, 24, 2)); clean(ax2)
low = h.loc[h.sla_met_pct.idxmin()]
ax2.annotate(f"{low.sla_met_pct:.0f}% at {int(low.hour)}:00", (low.hour, low.sla_met_pct), xytext=(low.hour - 6.5, 48),
             color=INK, fontsize=9, arrowprops=dict(arrowstyle="-", color=INK2))
fig.tight_layout(); fig.savefig(OUT / "chart_hourly_demand_speed.png", dpi=160); plt.close(fig)
print("      wrote docs/chart_*.png")
