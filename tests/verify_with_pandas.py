#!/usr/bin/env python3
"""Independent cross-check: recompute key SQL results from the RAW CSVs with pandas (different code path, different
engine) and compare with PostgreSQL. Any mismatch exits non-zero."""
import io, pathlib, subprocess, sys
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parent.parent
D = ROOT / "data"


def run(args):
    r = subprocess.run(["psql", "-X", "-q", "--csv", "-v", "ON_ERROR_STOP=1"] + args, capture_output=True, text=True)
    if r.returncode: sys.exit(r.stderr)
    return pd.read_csv(io.StringIO(r.stdout))


sql = lambda text: run(["-c", text])
sqlfile = lambda name: run(["-f", str(ROOT / "03_analysis" / name)])

o = pd.read_csv(D / "orders.csv")
o["status"] = o.status.str.strip().str.lower().replace({"canceled": "cancelled"})
d = o[o.status == "delivered"].copy()
d["t0"] = pd.to_datetime(d.order_ts); d["t1"] = pd.to_datetime(d.delivered_ts)
d["dq"] = d.t1.isna() | (d.t1 < d.t0)
d["dm"] = (d.t1 - d.t0).dt.total_seconds() / 60

checks = []
s = sql("SELECT round(sum(amount_paid), 2) AS rev, count(*) AS n, count(DISTINCT customer_id) AS c FROM qc.v_delivered_orders").iloc[0]
checks += [("delivered revenue (Rs)", round(d.amount_paid.sum(), 2), float(s.rev)),
           ("delivered orders", len(d), int(s.n)),
           ("customers with a delivered order", d.customer_id.nunique(), int(s.c))]

# Q9: top-20% revenue share (NTILE(10) gives the first n%10 groups one extra row)
spend = d.groupby("customer_id").amount_paid.sum().sort_values(ascending=False)
N = len(spend); k = 2 * (N // 10) + min(N % 10, 2)
q9 = sqlfile("q09_revenue_concentration.sql")
checks.append(("Q9 top-20% revenue share (%)", round(100 * spend.iloc[:k].sum() / spend.sum(), 1),
               float(q9.loc[q9.customer_decile <= 2, "pct_of_revenue"].sum().round(1))))

# Q8: 30-day reorder rate by delivery time of the first order
d = d.sort_values(["customer_id", "t0"])
first = d.groupby("customer_id").head(1)
maxts = d.t0.max()
el = first[(first.t0 <= maxts - pd.Timedelta(days=30)) & ~first.dq].copy()
later = d[["customer_id", "t0"]].rename(columns={"t0": "t2"})
m = el.merge(later, on="customer_id")
m = m[(m.t2 > m.t0) & (m.t2 <= m.t0 + pd.Timedelta(days=30))]
el["rep"] = el.customer_id.isin(set(m.customer_id))
el["bucket"] = pd.cut(el.dm, [-1, 10, 15, 20, 1e9], labels=["1  up to 10 min", "2  11-15 min", "3  16-20 min", "4  over 20 min"])
q8 = sqlfile("q08_slow_first_delivery_vs_reorder.sql").set_index("first_order_delivery_time")
for lab in q8.index:
    sub = el[el.bucket == lab]
    checks.append((f"Q8 customers ({lab.strip()})", len(sub), int(q8.loc[lab, "customers"])))
    checks.append((f"Q8 reorder rate % ({lab.strip()})", round(100 * sub.rep.mean(), 1), float(q8.loc[lab, "reorder_30d_pct"])))

# RFM: materialised view segment sizes must equal the Q4 query
q4 = sqlfile("q04_rfm_segmentation.sql").set_index("segment").customers
mv = sql("SELECT segment, count(*) AS customers FROM qc.mv_rfm GROUP BY 1").set_index("segment").customers
checks.append(("RFM: mv_rfm segment sizes == Q4", int((q4.sort_index() == mv.sort_index()).all()), 1))
# cleaning proof: lines + fees - discount == amount_paid on every order (SQL-side count of mismatches must be 0)
bad = int(sql("""SELECT count(*) AS n FROM qc.orders o JOIN (SELECT order_id, sum(quantity*unit_price) v FROM qc.order_items GROUP BY 1) i
                 USING (order_id) WHERE abs(i.v + o.delivery_fee + o.handling_fee - o.discount_amount - o.amount_paid) > 0.011""").n[0])
checks.append(("orders where lines+fees-discount <> paid", 0, bad))

fails = 0
print(f"{'check':46s}{'pandas':>16s}{'postgres':>16s}  result")
for name, a, b in checks:
    ok = abs(a - b) < 0.011; fails += not ok
    print(f"{name:46s}{a:>16,}{b:>16,}  {'OK' if ok else 'MISMATCH'}")
sys.exit(1 if fails else 0)
