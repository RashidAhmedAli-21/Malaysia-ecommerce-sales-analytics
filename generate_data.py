"""Generate a synthetic Malaysian e-commerce dataset (2024-2025) for the portfolio project.
Outputs CSVs plus a MySQL seed file with INSERT statements.
The data is synthetic (fake) and labelled as such in the README."""
import csv, random, sys, os
from datetime import date, timedelta

random.seed(42)
OUT = sys.argv[1]
os.makedirs(f"{OUT}/data/raw", exist_ok=True)
os.makedirs(f"{OUT}/sql", exist_ok=True)

states = [("Kuala Lumpur", "Central"), ("Selangor", "Central"), ("Putrajaya", "Central"),
          ("Penang", "Northern"), ("Kedah", "Northern"), ("Perak", "Northern"), ("Perlis", "Northern"),
          ("Johor", "Southern"), ("Melaka", "Southern"), ("Negeri Sembilan", "Southern"),
          ("Pahang", "East Coast"), ("Terengganu", "East Coast"), ("Kelantan", "East Coast"),
          ("Sabah", "East Malaysia"), ("Sarawak", "East Malaysia"), ("Labuan", "East Malaysia")]
state_w = [14, 22, 2, 9, 5, 7, 1, 11, 4, 4, 4, 3, 3, 5, 5, 1]
messy = {"Kuala Lumpur": ["KL", "kuala lumpur", "Kuala Lumpur "], "Selangor": ["selangor", "SELANGOR", "Selangor "],
         "Penang": ["Pulau Pinang", "penang"], "Johor": ["johor", "Johor Bahru"]}

categories = {
    "Electronics": [("Wireless Earbuds", 129), ("Power Bank 20000mAh", 89), ("Smartwatch", 349), ("Bluetooth Speaker", 159), ("USB-C Charger 65W", 69), ("Mechanical Keyboard", 229)],
    "Fashion": [("Baju Kurung Set", 119), ("Men's Batik Shirt", 89), ("Sneakers", 199), ("Tudung Bawal", 35), ("Denim Jeans", 109)],
    "Home & Living": [("Rice Cooker 1.8L", 159), ("Air Fryer 4L", 239), ("Bedsheet Set", 99), ("Standing Fan", 129), ("Cookware Set", 189)],
    "Health & Beauty": [("Sunscreen SPF50", 45), ("Facial Cleanser", 32), ("Vitamin C 1000mg", 55), ("Hair Dryer", 89), ("Perfume 50ml", 149)],
    "Groceries": [("Basmati Rice 5kg", 38), ("Coffee 3-in-1 (40 sachets)", 26), ("Cooking Oil 5L", 32), ("Instant Noodles (30 pack)", 29)],
    "Sports & Outdoor": [("Yoga Mat", 59), ("Badminton Racket", 179), ("Dumbbell Set 10kg", 129), ("Camping Tent 4P", 259)],
}
cat_w = {"Electronics": 24, "Fashion": 22, "Home & Living": 18, "Health & Beauty": 16, "Groceries": 12, "Sports & Outdoor": 8}

first = ["Ahmad", "Nur", "Siti", "Muhammad", "Aisyah", "Wei Jie", "Mei Ling", "Jia Hui", "Kumar", "Priya", "Arjun", "Farah", "Daniel", "Hafiz", "Lim", "Tan", "Rajesh", "Amirah", "Zul", "Chloe"]
last = ["Abdullah", "Ismail", "Rahman", "Tan", "Lim", "Wong", "Lee", "Raj", "Subramaniam", "Hassan", "Ibrahim", "Chong", "Ng", "Yusof", "Ali"]

# ---------- categories & products ----------
cat_rows, prod_rows = [], []
pid = 1
for cid, (cname, items) in enumerate(categories.items(), start=1):
    cat_rows.append((cid, cname))
    for pname, price in items:
        cost = round(price * random.uniform(0.55, 0.72), 2)
        prod_rows.append((pid, pname, cid, float(price), cost))
        pid += 1
prods_by_cat = {}
for p in prod_rows:
    prods_by_cat.setdefault(p[2], []).append(p)

# ---------- customers ----------
N_CUST = 1500
cust_rows, raw_cust = [], []
start = date(2024, 1, 1)
for i in range(1, N_CUST + 1):
    st, region = random.choices(states, weights=state_w)[0]
    fn, ln = random.choice(first), random.choice(last)
    email = f"{fn.lower().replace(' ', '')}.{ln.lower()}{i}@example.com"
    signup = start + timedelta(days=random.randint(0, 700))
    age = random.choices([random.randint(18, 24), random.randint(25, 34), random.randint(35, 44), random.randint(45, 60)], weights=[25, 40, 22, 13])[0]
    cust_rows.append((i, f"{fn} {ln}", email, age, st, signup.isoformat()))
    # messy raw version for the cleaning step
    raw_state = random.choice(messy[st]) if st in messy and random.random() < 0.25 else st
    raw_email = email.upper() if random.random() < 0.05 else email
    if random.random() < 0.03:
        raw_email = ""
    raw_name = f"  {fn} {ln} " if random.random() < 0.05 else f"{fn} {ln}"
    raw_cust.append((i, raw_name, raw_email, age, raw_state, signup.isoformat()))
# add exact and near duplicates
for i in random.sample(range(N_CUST), 60):
    raw_cust.append(raw_cust[i])

# ---------- orders ----------
def day_weight(d):
    w = 1.0
    if d.month == 11 and d.day == 11: w *= 4.5
    if d.month == 12 and d.day == 12: w *= 3.5
    if d.month in (11, 12): w *= 1.3
    if (d.year == 2024 and d.month == 3 and d.day >= 25) or (d.year == 2024 and d.month == 4 and d.day <= 10): w *= 1.6  # Raya 2024
    if (d.year == 2025 and d.month == 3 and d.day >= 15) or (d.year == 2025 and d.month == 3 and d.day <= 31): w *= 1.6  # Raya 2025
    if d.weekday() >= 5: w *= 1.15
    w *= 1 + 0.35 * ((d - start).days / 730)  # growth trend
    return w

days = [start + timedelta(days=k) for k in range(731)]
dw = [day_weight(d) for d in days]
N_ORD = 6000
order_rows, item_rows = [], []
pay_methods, pay_w = ["Online Banking (FPX)", "E-Wallet", "Credit/Debit Card", "Cash on Delivery"], [30, 34, 26, 10]
status_opts, status_w = ["Completed", "Cancelled", "Returned"], [90, 6, 4]
iid = 1
cust_signup = {c[0]: date.fromisoformat(c[5]) for c in cust_rows}
loyal = random.sample(range(1, N_CUST + 1), 250)
for oid in range(1, N_ORD + 1):
    d = random.choices(days, weights=dw)[0]
    cand = random.choice(loyal) if random.random() < 0.35 else random.randint(1, N_CUST)
    if cust_signup[cand] > d:
        cand_pool = [c for c in random.sample(range(1, N_CUST + 1), 40) if cust_signup[c] <= d]
        cand = cand_pool[0] if cand_pool else 1
    pm = random.choices(pay_methods, weights=pay_w)[0]
    status = random.choices(status_opts, weights=status_w)[0]
    if pm == "Cash on Delivery" and random.random() < 0.10:
        status = "Cancelled"
    order_rows.append((oid, cand, d.isoformat(), pm, status))
    for _ in range(random.choices([1, 2, 3, 4], weights=[55, 28, 12, 5])[0]):
        cat = random.choices(list(cat_w), weights=list(cat_w.values()))[0]
        cid = [c[0] for c in cat_rows if c[1] == cat][0]
        p = random.choice(prods_by_cat[cid])
        qty = random.choices([1, 2, 3], weights=[75, 20, 5])[0]
        disc = 0.0
        if (d.month == 11 and d.day == 11) or (d.month == 12 and d.day == 12):
            disc = random.choice([0.10, 0.15, 0.20])
        elif random.random() < 0.15:
            disc = random.choice([0.05, 0.10])
        item_rows.append((iid, oid, p[0], qty, p[3], disc))
        iid += 1

# ---------- write CSVs ----------
def wcsv(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

wcsv(f"{OUT}/data/raw/customers_raw.csv", ["customer_id", "full_name", "email", "age", "state", "signup_date"], raw_cust)
wcsv(f"{OUT}/data/raw/categories.csv", ["category_id", "category_name"], cat_rows)
wcsv(f"{OUT}/data/raw/products.csv", ["product_id", "product_name", "category_id", "unit_price", "unit_cost"], prod_rows)
wcsv(f"{OUT}/data/raw/orders.csv", ["order_id", "customer_id", "order_date", "payment_method", "order_status"], order_rows)
wcsv(f"{OUT}/data/raw/order_items.csv", ["order_item_id", "order_id", "product_id", "quantity", "unit_price", "discount_pct"], item_rows)

# ---------- MySQL seed file ----------
def q(v):
    if v is None: return "NULL"
    if isinstance(v, (int, float)): return repr(v)
    return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"

def inserts(f, table, cols, rows, chunk=500):
    for k in range(0, len(rows), chunk):
        vals = ",\n".join("(" + ",".join(q(v) for v in r) + ")" for r in rows[k:k + chunk])
        f.write(f"INSERT INTO {table} ({','.join(cols)}) VALUES\n{vals};\n")

with open(f"{OUT}/sql/02_load_data.sql", "w", encoding="utf-8") as f:
    f.write("-- 02_load_data.sql : loads the synthetic dataset (generated by generate_data.py, seed 42)\n")
    f.write("USE malaysia_ecommerce;\nSET FOREIGN_KEY_CHECKS = 0;\n\n")
    f.write("-- Raw customers go to a staging table first (they contain duplicates and messy values)\n")
    inserts(f, "stg_customers_raw", ["customer_id", "full_name", "email", "age", "state", "signup_date"], raw_cust)
    inserts(f, "categories", ["category_id", "category_name"], cat_rows)
    inserts(f, "products", ["product_id", "product_name", "category_id", "unit_price", "unit_cost"], prod_rows)
    f.write("SET FOREIGN_KEY_CHECKS = 1;\n\n-- Orders and items are loaded after customers are cleaned (see 03_clean_customers.sql)\n")
with open(f"{OUT}/sql/03b_load_orders.sql", "w", encoding="utf-8") as f:
    f.write("-- 03b_load_orders.sql : run AFTER 03_clean_customers.sql\nUSE malaysia_ecommerce;\n\n")
    inserts(f, "orders", ["order_id", "customer_id", "order_date", "payment_method", "order_status"], order_rows)
    inserts(f, "order_items", ["order_item_id", "order_id", "product_id", "quantity", "unit_price", "discount_pct"], item_rows)

print(len(raw_cust), len(order_rows), len(item_rows), len(prod_rows))
