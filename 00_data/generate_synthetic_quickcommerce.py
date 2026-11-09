#!/usr/bin/env python3
"""
Generate a SYNTHETIC Indian quick-commerce dataset (10-minute grocery delivery from neighbourhood "dark stores",
the model used by Blinkit, Zepto and Swiggy Instamart).

This is NOT data from Blinkit or any real company, and it is not real customer data. Names, prices and behaviour are
invented. Several behaviours (slow delivery raises churn, first-order coupons attract less loyal customers, rain slows
delivery) are ASSUMPTIONS written into this generator, so findings on this data illustrate the SQL method only.

Realistic India-specific details: 10 cities incl. Delhi NCR / Mumbai / Bengaluru, INR prices, UPI / COD / wallet
payments, city-name spelling variants (Bangalore/Bengaluru, Gurgaon/Gurugram), free delivery above Rs 199, evening and
morning demand peaks, Holi and Diwali demand lifts, monsoon rain delays. Deterministic: fixed seed.

Usage: python3 generate_synthetic_quickcommerce.py [out_dir] [n_customers]
"""
import bisect, os, random, sys
from datetime import datetime, timedelta
import numpy as np
import pandas as pd

SEED = 7
OUT = sys.argv[1] if len(sys.argv) > 1 else "data"
N_CUSTOMERS = int(sys.argv[2]) if len(sys.argv) > 2 else 40000
START, END = datetime(2025, 1, 1), datetime(2025, 12, 31, 23, 59, 59)
rnd = random.Random(SEED)
nrng = np.random.default_rng(SEED)
os.makedirs(OUT, exist_ok=True)
fmt = lambda t: t.strftime("%Y-%m-%d %H:%M:%S")
cum = lambda w: np.cumsum(np.array(w) / np.sum(w)).tolist()
pick = lambda c: min(bisect.bisect(c, rnd.random()), len(c) - 1)

# ------------------------------------------------------------------ cities
CITIES = [(1, "Delhi NCR", 1, .24), (2, "Mumbai", 1, .18), (3, "Bengaluru", 1, .17), (4, "Hyderabad", 1, .09),
          (5, "Pune", 1, .08), (6, "Chennai", 1, .07), (7, "Kolkata", 1, .06), (8, "Ahmedabad", 2, .04),
          (9, "Jaipur", 2, .04), (10, "Lucknow", 2, .03)]
CITY_CUM = cum([c[3] for c in CITIES])
RAW_CITY = {1: ["Delhi", "New Delhi", "Gurgaon", "Gurugram", "Noida", "Delhi NCR"], 2: ["Mumbai", "Bombay", "Navi Mumbai", "Thane", "mumbai"],
            3: ["Bengaluru", "Bangalore", "Bengaluru ", "bangalore"], 4: ["Hyderabad", "hyderabad", "Hyderbad"],
            5: ["Pune", "pune"], 6: ["Chennai", "chennai"], 7: ["Kolkata", "Calcutta", "kolkata"],
            8: ["Ahmedabad", "Ahmadabad"], 9: ["Jaipur", "jaipur"], 10: ["Lucknow", "Lucknow "]}
LOCALITIES = {
 1: ["Dwarka", "Saket", "Rohini", "Lajpat Nagar", "Vasant Kunj", "Pitampura", "Janakpuri", "Mayur Vihar", "Karol Bagh",
     "Gurugram Sector 56", "Gurugram DLF Phase 3", "Noida Sector 62", "Noida Sector 18", "Indirapuram", "Greater Kailash", "Hauz Khas"],
 2: ["Andheri West", "Bandra West", "Powai", "Thane West", "Borivali", "Dadar", "Lower Parel", "Malad", "Goregaon", "Vashi", "Chembur", "Juhu"],
 3: ["Koramangala", "Indiranagar", "HSR Layout", "Whitefield", "Jayanagar", "Electronic City", "Marathahalli", "BTM Layout", "Hebbal", "JP Nagar", "Bellandur", "Malleshwaram"],
 4: ["Gachibowli", "Hitech City", "Madhapur", "Kondapur", "Banjara Hills", "Jubilee Hills", "Kukatpally", "Secunderabad"],
 5: ["Kothrud", "Baner", "Hinjewadi", "Viman Nagar", "Wakad", "Hadapsar", "Koregaon Park"],
 6: ["Adyar", "T Nagar", "Velachery", "Anna Nagar", "Sholinganallur", "Tambaram"],
 7: ["Salt Lake", "New Town", "Park Street", "Behala", "Dum Dum", "Howrah"],
 8: ["Satellite", "Bopal", "Navrangpura", "Maninagar"], 9: ["Vaishali Nagar", "Malviya Nagar", "C-Scheme"],
 10: ["Gomti Nagar", "Hazratganj", "Indira Nagar"]}
CITY_EXTRA_MIN = {1: 1.2, 2: 1.5, 3: 0.8, 4: 0.4, 5: 0.3, 6: 0.3, 7: 1.0, 8: 0, 9: 0, 10: 0}

# ------------------------------------------------------------ dark stores
stores, stores_by_city, closed = [], {c[0]: [] for c in CITIES}, {}
sid = 0
for cid, _, _, w in CITIES:
    n = max(3, round(120 * w))
    for k in range(n):
        sid += 1
        loc = LOCALITIES[cid][k % len(LOCALITIES[cid])] + ("" if k < len(LOCALITIES[cid]) else f" {k // len(LOCALITIES[cid]) + 1}")
        opened = START if (k == 0 or rnd.random() < .7) else START + timedelta(days=rnd.randint(30, 240))
        stores.append(dict(store_id=sid, city=rnd.choice(RAW_CITY[cid]), locality=loc, opened_date=opened.strftime("%Y-%m-%d")))
        stores_by_city[cid].append((sid, opened))
        closed[sid] = {(START + timedelta(days=d)).date() for d in rnd.sample(range(365), rnd.randint(5, 16))}  # outage days
stores = pd.DataFrame(stores)

# ------------------------------------------------------------------ weather
rain = {}
for cid, *_ in CITIES:
    for d in range(365):
        day = (START + timedelta(days=d)).date()
        monsoon = datetime(2025, 6, 15).date() <= day <= datetime(2025, 9, 30).date()
        mm = 0.0
        if rnd.random() < (0.45 if monsoon else 0.06):
            mm = round(min(120, max(0.5, rnd.lognormvariate(2.2, 0.9))), 1)
        rain[(cid, day)] = mm
weather = pd.DataFrame([dict(city_id=c, day=str(d), rainfall_mm=mm) for (c, d), mm in rain.items()])

# ----------------------------------------------------------------- products
CATS = {
 "Fruits & Vegetables": (.16, 40, ["Onion", "Potato", "Tomato", "Banana", "Apple", "Coriander", "Capsicum", "Lemon"]),
 "Dairy, Bread & Eggs": (.17, 60, ["Toned Milk", "Full Cream Milk", "Curd", "Paneer", "Butter", "Brown Bread", "White Bread", "Eggs"]),
 "Atta, Rice & Dal": (.07, 250, ["Whole Wheat Atta", "Basmati Rice", "Toor Dal", "Moong Dal", "Sona Masoori Rice", "Besan"]),
 "Oil & Masala": (.05, 180, ["Sunflower Oil", "Mustard Oil", "Turmeric Powder", "Red Chilli Powder", "Garam Masala", "Salt"]),
 "Snacks & Munchies": (.14, 40, ["Potato Chips", "Namkeen Mix", "Instant Noodles", "Biscuits", "Popcorn", "Nachos"]),
 "Cold Drinks & Juices": (.12, 50, ["Cola", "Lemon Soda", "Mango Juice", "Energy Drink", "Packaged Water", "Iced Tea"]),
 "Sweet Tooth": (.06, 90, ["Chocolate Bar", "Ice Cream Tub", "Gulab Jamun Tin", "Cookies", "Candy Pack"]),
 "Tea, Coffee & Health Drinks": (.04, 220, ["Tea Powder", "Instant Coffee", "Green Tea", "Malt Drink", "Protein Powder"]),
 "Breakfast & Instant Food": (.05, 160, ["Corn Flakes", "Oats", "Peanut Butter", "Instant Poha", "Pasta", "Ready Soup"]),
 "Cleaning Essentials": (.04, 150, ["Dishwash Liquid", "Floor Cleaner", "Detergent Powder", "Toilet Cleaner", "Garbage Bags"]),
 "Personal Care": (.05, 180, ["Shampoo", "Face Wash", "Toothpaste", "Soap Bar", "Deodorant", "Sanitary Pads"]),
 "Baby Care": (.015, 350, ["Diapers", "Baby Wipes", "Baby Lotion", "Infant Cereal"]),
 "Pet Care": (.01, 400, ["Dog Food", "Cat Food", "Pet Treats"]),
 "Electronics & Accessories": (.01, 350, ["USB Cable", "Earphones", "Power Bank", "Batteries"]),
}
cat_names = list(CATS)
CAT_CUM = cum([CATS[c][0] for c in cat_names])
COMPLEMENT = {1: 8, 8: 1, 4: 5, 5: 4, 2: 3, 3: 2, 7: 6, 6: 7, 10: 9, 9: 10}      # category index pairs bought together
SIZES = [("250 g", .6), ("500 g", 1.0), ("1 kg", 1.8)]
BRANDS = ["Brand A", "Brand B", "Brand C", "Brand D"]
prods, prod_by_cat = [], {i: [] for i in range(len(cat_names))}
for ci, cn in enumerate(cat_names):
    _, med, bases = CATS[cn]
    for b in bases:
        for br in BRANDS:
            for sz, f in SIZES:
                pid = len(prods) + 1
                mrp = max(5, round(med * f * rnd.uniform(.8, 1.3) * rnd.lognormvariate(0, .2)))
                prods.append(dict(product_id=pid, category_name=cn, product_name=f"{b} - {br} {sz}", mrp=mrp))
                prod_by_cat[ci].append((pid, mrp))
    rnd.shuffle(prod_by_cat[ci])
products = pd.DataFrame(prods)
PCUM = {ci: cum([1 / (r + 1) ** 0.9 for r in range(len(l))]) for ci, l in prod_by_cat.items()}

# ------------------------------------------------------------- demand shape
HOUR_CUM = cum([.5, .3, .1, .05, .05, .2, 1, 2.5, 4, 3.5, 2.5, 2.5, 3, 2.5, 2, 2.2, 2.8, 3.5, 4.5, 6, 6.5, 6, 4.5, 2])
PEAK = {8, 9, 19, 20, 21}
PAY = ["UPI", "CARD", "COD", "WALLET", "NETBANKING"]; PAY_CUM = cum([.58, .17, .12, .08, .05])
CHAN = ["organic", "paid_social", "referral", "influencer", "app_store"]; CHAN_CUM = cum([.38, .22, .14, .10, .16])
COUPON_P = {"organic": .20, "paid_social": .65, "referral": .70, "influencer": .60, "app_store": .45}
FEST = [(datetime(2025, 3, 8), datetime(2025, 3, 16)), (datetime(2025, 10, 12), datetime(2025, 10, 21))]  # Holi, Diwali
mw = np.linspace(1, 3, 12); mw[2] *= 1.3; mw[9] *= 1.4; MONTH_CUM = cum(mw)
RATING_W = {0: [.02, .03, .08, .25, .62], 1: [.05, .07, .15, .33, .40], 2: [.15, .18, .22, .25, .20], 3: [.30, .25, .20, .15, .10]}
TAGS_LOW = ["delivery_speed", "missing_item", "item_quality", "packaging", "rider_behaviour"]


def bucket(dm):
    return 0 if dm <= 10 else 1 if dm <= 15 else 2 if dm <= 20 else 3


orders, items, feedback, customers = [], [], [], []
oid = 0


def make_order(cust, store, cid, ts, is_first, coupon_first):
    global oid
    oid += 1
    day = ts.date()
    rain_mm = rain[(cid, day)]
    n_it = rnd.choices([1, 2, 3, 4, 5, 6, 7], [.20, .25, .20, .15, .10, .06, .04])[0]
    # basket: each extra item is 35% likely to come from the complementary category (milk+bread, chips+cola ...)
    ci = pick(CAT_CUM); lines, iv = [], 0.0
    for ln in range(1, n_it + 1):
        if ln > 1 and ci in COMPLEMENT and rnd.random() < .35: ci = COMPLEMENT[ci]
        elif ln > 1: ci = pick(CAT_CUM)
        pid, mrp = prod_by_cat[ci][pick(PCUM[ci])]
        qty = rnd.choices([1, 2, 3], [.8, .15, .05])[0]
        price = round(mrp * (1 - rnd.uniform(0, .12)), 2)
        lines.append((oid, ln, pid, qty, price)); iv += qty * price
    iv = round(iv, 2)
    peak = ts.hour in PEAK
    delivery_fee = 0.0 if iv >= 199 else float(rnd.choice([25, 30, 35]))
    handling = 2.0 + (3.0 if peak else 0.0) + (5.0 if rain_mm >= 10 else 0.0)
    discount = 0.0
    if is_first and coupon_first: discount = float(min(rnd.choice([50, 75, 100, 120]), iv * .6))
    elif rnd.random() < .12: discount = float(min(rnd.choice([20, 30, 40, 60]), iv * .5))
    discount = round(discount, 2)
    paid = round(iv + delivery_fee + handling - discount, 2)
    mean = 7.8 + (2.0 if peak else 0) + (4.5 if rain_mm >= 10 else 1.5 if rain_mm >= 2 else 0) + CITY_EXTRA_MIN[cid]
    dm = max(3.0, rnd.lognormvariate(np.log(mean) - .5 * .4 ** 2, .4) + (rnd.uniform(6, 15) if rnd.random() < .03 else 0))
    cancelled = rnd.random() < .025
    delivered = None if cancelled else ts + timedelta(minutes=dm)
    promised = 10 if n_it <= 3 else 15
    orders.append((oid, cust, store, fmt(ts), promised, fmt(delivered) if delivered else "", "cancelled" if cancelled else "delivered",
                   PAY[pick(PAY_CUM)], delivery_fee, handling, discount, paid))
    items.extend(lines)
    rating = None
    if not cancelled and rnd.random() < .35:
        rating = rnd.choices([1, 2, 3, 4, 5], RATING_W[bucket(dm)])[0]
        feedback.append((oid, rating, rnd.choice(TAGS_LOW) if rating <= 2 else "", fmt(delivered + timedelta(minutes=rnd.randint(5, 600)))))
    return cancelled, dm, rating


for c in range(1, N_CUSTOMERS + 1):
    cid = CITIES[pick(CITY_CUM)][0]
    channel = CHAN[pick(CHAN_CUM)]
    coupon_first = rnd.random() < COUPON_P[channel]
    m = pick(MONTH_CUM)
    ts = datetime(2025, m + 1, 1) + timedelta(days=rnd.randrange(28), hours=0)
    ts = ts.replace(hour=pick(HOUR_CUM), minute=rnd.randrange(60), second=rnd.randrange(60))
    open_stores = [s for s, o in stores_by_city[cid] if o <= ts] or [stores_by_city[cid][0][0]]
    store = rnd.choice(open_stores)
    base_churn = rnd.betavariate(2, 14)               # mean ~12.5% chance to stop after any order
    gap_mean = rnd.lognormvariate(np.log(8), .5)      # typical days between orders for this person
    signup = ts
    first = True
    while True:
        while ts.date() in closed[store]: ts += timedelta(days=1)         # store outage: order slides to next day
        if ts > END: break
        cancelled, dm, rating = make_order(c, store, cid, ts, first, coupon_first)
        p = .30 if cancelled else min(.9, base_churn + (.14 if dm > 20 else .07 if dm > 15 else .02 if dm > 10 else 0)
                                       + (.05 if coupon_first else 0) + (.06 if rating and rating <= 2 else 0))
        first = False
        if rnd.random() < p: break
        gap = rnd.expovariate(1 / gap_mean) + .3
        if any(a <= ts <= b for a, b in FEST): gap *= .6
        nxt = (ts + timedelta(days=gap)).replace(hour=pick(HOUR_CUM), minute=rnd.randrange(60), second=rnd.randrange(60))
        if nxt <= ts: nxt = ts + timedelta(hours=6)
        ts = nxt
    customers.append(dict(customer_id=c, signup_date=signup.strftime("%Y-%m-%d"), city=rnd.choice(RAW_CITY[cid]),
                          acquisition_channel=channel))

cols_o = ["order_id", "customer_id", "store_id", "order_ts", "promised_minutes", "delivered_ts", "status", "payment_method",
          "delivery_fee", "handling_fee", "discount_amount", "amount_paid"]
O = pd.DataFrame(orders, columns=cols_o)
I = pd.DataFrame(items, columns=["order_id", "line_no", "product_id", "quantity", "unit_price"])
F = pd.DataFrame(feedback, columns=["order_id", "rating", "tag", "created_ts"])
C = pd.DataFrame(customers)

# ------------------------------------------- inject realistic data-quality issues
def vary(series, variants):
    out = series.copy()
    for k, v in variants.items():
        idx = out.index[out == k]
        sel = nrng.random(len(idx)) < .35
        out.loc[idx[sel]] = nrng.choice(v, sel.sum())
    return out
O["payment_method"] = vary(O.payment_method, {"UPI": ["upi", "Upi "], "CARD": ["Card", "Credit Card", "Debit Card", "card"],
                                              "COD": ["cod", "Cash on Delivery"], "WALLET": ["Wallet"], "NETBANKING": ["Net Banking", "NetBanking"]})
O["status"] = vary(O.status, {"delivered": ["Delivered", "DELIVERED"], "cancelled": ["Cancelled", "canceled"]})
C["acquisition_channel"] = vary(C.acquisition_channel, {"organic": ["Organic", "organic "], "paid_social": ["Paid Social", "Paid_Social"],
                                                        "referral": ["Referral", "REFERRAL"], "influencer": ["Influencer"], "app_store": ["App Store"]})
deliv = O.index[O.status.str.lower() == "delivered"].to_numpy()
pk = nrng.choice(deliv, 700, replace=False)
for i in pk[:400]:     # delivered BEFORE the order was placed
    O.at[i, "delivered_ts"] = fmt(datetime.strptime(O.at[i, "order_ts"], "%Y-%m-%d %H:%M:%S") - timedelta(minutes=rnd.randint(1, 60)))
for i in pk[400:]:     # status delivered, no timestamp
    O.at[i, "delivered_ts"] = ""
canc = O.index[O.status.str.lower().isin(["cancelled", "canceled"])].to_numpy()
for i in nrng.choice(canc, 150, replace=False):   # cancelled but has a delivery time
    O.at[i, "delivered_ts"] = fmt(datetime.strptime(O.at[i, "order_ts"], "%Y-%m-%d %H:%M:%S") + timedelta(minutes=20))
dupI = I.sample(frac=.005, random_state=1)                                       # double-posted lines
zeroI = I.sample(n=60, random_state=2).copy(); zeroI["line_no"] = 99; zeroI["quantity"] = 0   # junk zero-quantity lines
I = pd.concat([I, dupI, zeroI]).sample(frac=1, random_state=3).reset_index(drop=True)
bad = F.sample(n=80, random_state=4).copy(); bad["rating"] = nrng.choice([0, 6], 80)          # impossible ratings
dupF = F.sample(frac=.01, random_state=5).copy(); dupF["created_ts"] = dupF.created_ts
F = pd.concat([F, bad, dupF]).sample(frac=1, random_state=6).reset_index(drop=True)

cities = pd.DataFrame([(c[0], c[1], c[2]) for c in CITIES], columns=["city_id", "city_name", "tier"])
for name, df in [("cities", cities), ("stores", stores), ("customers", C), ("products", products), ("orders", O),
                 ("order_items", I), ("order_feedback", F), ("weather_daily", weather)]:
    df.to_csv(os.path.join(OUT, f"{name}.csv"), index=False)
    print(f"{name:16s}{len(df):>10,d} rows")
dm = O[O.status.str.lower() == "delivered"]
print(f"customers {len(C):,}; orders per customer {len(O) / len(C):.2f}; cancelled {(len(O) - len(dm)) / len(O):.1%}")
