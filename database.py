"""
database.py — SQLite connection, one-time seed from clerks-products.sql,
              and all helper functions for users, basket, wishlist, orders, stores.
"""
import sqlite3
import os
import re
import random
import hashlib
import uuid
from datetime import datetime, timedelta

DB_PATH = "clerks_v2.db"
SQL_PATH = "clerks-products.sql"


def _load_sql() -> str:
    """Read the SQL seed file and patch MySQL-only syntax for SQLite."""
    with open(SQL_PATH, "r", encoding="utf-8") as f:
        sql = f.read()
    sql = re.sub(
        r"\bINT\s+PRIMARY KEY\s+AUTO_INCREMENT\b",
        "INTEGER PRIMARY KEY AUTOINCREMENT",
        sql,
        flags=re.IGNORECASE,
    )
    sql = sql.replace("AUTO_INCREMENT", "AUTOINCREMENT")
    return sql


def _split_statements(sql: str) -> list[str]:
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    sql = re.sub(r"--[^\n]*", "", sql)
    statements = [s.strip() for s in sql.split(";")]
    return [s for s in statements if s]


def _get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


# ── Schema creation ────────────────────────────────────────────────────────────

def init_user_db(conn: sqlite3.Connection) -> None:
    """Create all user-related tables if they don't already exist."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            email        TEXT    NOT NULL UNIQUE COLLATE NOCASE,
            password_hash TEXT   NOT NULL,
            first_name   TEXT    NOT NULL,
            last_name    TEXT    NOT NULL DEFAULT '',
            phone        TEXT    NOT NULL DEFAULT '',
            address      TEXT    NOT NULL DEFAULT '',
            created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS basket_items (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            product_id TEXT    NOT NULL,
            size       REAL    NOT NULL,
            colour     TEXT    NOT NULL,
            qty        INTEGER NOT NULL DEFAULT 1,
            UNIQUE(user_id, product_id, size, colour)
        );

        CREATE TABLE IF NOT EXISTS wishlist_items (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            product_id TEXT    NOT NULL,
            UNIQUE(user_id, product_id)
        );

        CREATE TABLE IF NOT EXISTS orders (
            id         TEXT    PRIMARY KEY,
            user_id    INTEGER REFERENCES users(id) ON DELETE SET NULL,
            status     TEXT    NOT NULL,
            status_cls TEXT    NOT NULL,
            created_at TEXT    NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS order_items (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id   TEXT    NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
            product_id TEXT    NOT NULL,
            qty        INTEGER NOT NULL DEFAULT 1,
            size       REAL    NOT NULL,
            colour     TEXT    NOT NULL
        );

        CREATE TABLE IF NOT EXISTS order_steps (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id   TEXT    NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
            label      TEXT    NOT NULL,
            date_text  TEXT    NOT NULL,
            done       INTEGER NOT NULL DEFAULT 0,
            active     INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS stores (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            type       TEXT NOT NULL,
            type_label TEXT NOT NULL,
            type_class TEXT NOT NULL,
            address    TEXT NOT NULL,
            hours      TEXT NOT NULL,
            phone      TEXT NOT NULL
        );
    """)
    conn.commit()


# ── Store seed data ────────────────────────────────────────────────────────────

_STORES = [
    ("Clerks Oxford Street",          "both",   "Sport &amp; Formal", "lt-both",   "142 Oxford Street, London, W1D 1LT",                          "Mon–Sat 9am–8pm · Sun 11am–6pm",  "020 7123 4567"),
    ("Clerks Manchester Arndale",     "both",   "Sport &amp; Formal", "lt-both",   "Upper Mall East, Manchester Arndale, Manchester, M4 3AQ",      "Mon–Sat 9am–9pm · Sun 11am–5pm",  "0161 234 5678"),
    ("Clerks Birmingham Bullring",    "both",   "Sport &amp; Formal", "lt-both",   "Unit 128, Bullring Shopping Centre, Birmingham, B5 4BU",        "Mon–Sat 9am–9pm · Sun 11am–5pm",  "0121 345 6789"),
    ("Clerks Leeds Trinity",          "sport",  "Sport",              "lt-sport",  "27 Albion Street, Leeds Trinity, Leeds, LS1 5AT",              "Mon–Sat 9am–8pm · Sun 12pm–6pm",  "0113 456 7890"),
    ("Clerks Glasgow Buchanan",       "both",   "Sport &amp; Formal", "lt-both",   "220 Buchanan Street, Glasgow, G1 2GF",                         "Mon–Sat 9am–7pm · Sun 11am–5pm",  "0141 567 8901"),
    ("Clerks Edinburgh Princes St",   "formal", "Formal",             "lt-formal", "58 Princes Street, Edinburgh, EH2 2DG",                        "Mon–Sat 10am–7pm · Sun 12pm–5pm", "0131 678 9012"),
    ("Clerks Liverpool ONE",          "both",   "Sport &amp; Formal", "lt-both",   "Unit 42, Liverpool ONE, Liverpool, L1 8LG",                    "Mon–Sat 9am–9pm · Sun 11am–5pm",  "0151 789 0123"),
    ("Clerks Bristol Cabot Circus",   "sport",  "Sport",              "lt-sport",  "Unit 16, Cabot Circus, Bristol, BS1 3BX",                      "Mon–Sat 9am–8pm · Sun 11am–5pm",  "0117 890 1234"),
    ("Clerks Brighton Churchill Square","formal","Formal",            "lt-formal", "Churchill Square Shopping Centre, Brighton, BN1 2RG",           "Mon–Sat 9am–6pm · Sun 11am–5pm",  "01273 901 234"),
]

def seed_stores(conn: sqlite3.Connection) -> None:
    row = conn.execute("SELECT COUNT(*) FROM stores").fetchone()
    if row and row[0] > 0:
        return
    conn.executemany(
        "INSERT INTO stores (name, type, type_label, type_class, address, hours, phone) VALUES (?,?,?,?,?,?,?)",
        _STORES,
    )
    conn.commit()


# ── Demo order seed data ───────────────────────────────────────────────────────

def seed_demo_orders(conn: sqlite3.Connection) -> None:
    """Seed the 4 original demo track orders under user_id = NULL."""
    existing = conn.execute("SELECT id FROM orders WHERE id IN ('CLK-29418','CLK-30071','CLK-28854','CLK-31102')").fetchall()
    existing_ids = {r[0] for r in existing}

    demo_orders = [
        {
            "id": "CLK-29418", "status": "Delivered", "status_cls": "ts-delivered",
            "items": [("fm1", 1, 9, "Tan"), ("sp2", 1, 10, "Black")],
            "steps": [
                ("Order Placed",       "Tue 18 Jun, 09:14", 1, 0),
                ("Payment Confirmed",  "Tue 18 Jun, 09:15", 1, 0),
                ("Picking & Packing",  "Tue 18 Jun, 14:30", 1, 0),
                ("Dispatched",         "Wed 19 Jun, 08:00", 1, 0),
                ("Out for Delivery",   "Thu 20 Jun, 10:22", 1, 0),
                ("Delivered",          "Thu 20 Jun, 13:41", 1, 0),
            ],
        },
        {
            "id": "CLK-30071", "status": "Out for Delivery", "status_cls": "ts-transit",
            "items": [("sp14", 1, 9, "Blue")],
            "steps": [
                ("Order Placed",       "Mon 23 Jun, 18:42", 1, 0),
                ("Payment Confirmed",  "Mon 23 Jun, 18:43", 1, 0),
                ("Picking & Packing",  "Tue 24 Jun, 07:15", 1, 0),
                ("Dispatched",         "Tue 24 Jun, 11:00", 1, 0),
                ("Out for Delivery",   "Wed 25 Jun, 09:18", 1, 1),
                ("Delivered",          "Expected Wed 25 Jun", 0, 0),
            ],
        },
        {
            "id": "CLK-28854", "status": "Dispatched", "status_cls": "ts-dispatched",
            "items": [("fm5", 1, 8, "Tan")],
            "steps": [
                ("Order Placed",       "Fri 20 Jun, 11:03", 1, 0),
                ("Payment Confirmed",  "Fri 20 Jun, 11:04", 1, 0),
                ("Picking & Packing",  "Fri 20 Jun, 15:55", 1, 0),
                ("Dispatched",         "Sat 21 Jun, 09:30", 1, 1),
                ("Out for Delivery",   "Expected Wed 25 Jun", 0, 0),
                ("Delivered",          "Estimated Thu 26 Jun", 0, 0),
            ],
        },
        {
            "id": "CLK-31102", "status": "Processing", "status_cls": "ts-processing",
            "items": [("fm10", 1, 9, "Black"), ("sp7", 1, 10, "Olive")],
            "steps": [
                ("Order Placed",       "Wed 24 Jun, 14:07", 1, 1),
                ("Payment Confirmed",  "Wed 24 Jun, 14:08", 1, 0),
                ("Picking & Packing",  "Pending",           0, 0),
                ("Dispatched",         "Estimated Thu 25 Jun", 0, 0),
                ("Out for Delivery",   "Estimated Fri 26 Jun", 0, 0),
                ("Delivered",          "Estimated Fri 26 Jun", 0, 0),
            ],
        },
    ]

    for o in demo_orders:
        if o["id"] in existing_ids:
            continue
        conn.execute(
            "INSERT INTO orders (id, user_id, status, status_cls) VALUES (?,NULL,?,?)",
            (o["id"], o["status"], o["status_cls"]),
        )
        for i, (pid, qty, size, colour) in enumerate(o["items"]):
            conn.execute(
                "INSERT INTO order_items (order_id, product_id, qty, size, colour) VALUES (?,?,?,?,?)",
                (o["id"], pid, qty, size, colour),
            )
        for sort_i, (label, date_text, done, active) in enumerate(o["steps"]):
            conn.execute(
                "INSERT INTO order_steps (order_id, label, date_text, done, active, sort_order) VALUES (?,?,?,?,?,?)",
                (o["id"], label, date_text, done, active, sort_i),
            )
    conn.commit()


# ── Main init ──────────────────────────────────────────────────────────────────

def init_db() -> None:
    conn = _get_conn()
    try:
        # Existing products seed (unchanged logic)
        cursor = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
        )
        if not cursor.fetchone() or conn.execute("SELECT COUNT(*) FROM products").fetchone()[0] == 0:
            sql = _load_sql()
            statements = _split_statements(sql)
            for stmt in statements:
                try:
                    conn.execute(stmt)
                except sqlite3.Error as e:
                    if "no such table" not in str(e).lower():
                        raise
            conn.commit()

        # New tables
        init_user_db(conn)
        seed_stores(conn)
        seed_demo_orders(conn)
    finally:
        conn.close()


# ── Products (unchanged) ───────────────────────────────────────────────────────

async def fetch_products(store_type: str | None = None) -> list[dict]:
    import aiosqlite
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        if store_type:
            rows = await db.execute_fetchall(
                "SELECT * FROM products WHERE store_type = ?", (store_type,)
            )
        else:
            rows = await db.execute_fetchall("SELECT * FROM products ORDER BY id")

        products = []
        for row in rows:
            pid = row["id"]
            col_rows = await db.execute_fetchall(
                "SELECT colour_name, hex_code, img_url FROM product_colours WHERE product_id = ?", (pid,)
            )
            cols = [{"n": c["colour_name"], "h": c["hex_code"], "img": c["img_url"]} for c in col_rows]
            size_rows = await db.execute_fetchall(
                "SELECT size FROM product_sizes WHERE product_id = ? ORDER BY size", (pid,)
            )
            sizes = [float(s["size"]) if "." in str(s["size"]) else int(s["size"]) for s in size_rows]
            oos_rows = await db.execute_fetchall(
                "SELECT size FROM product_oos WHERE product_id = ? ORDER BY size", (pid,)
            )
            oos = [float(o["size"]) if "." in str(o["size"]) else int(o["size"]) for o in oos_rows]
            feat_rows = await db.execute_fetchall(
                "SELECT feature FROM product_features WHERE product_id = ? ORDER BY sort_order", (pid,)
            )
            feats = [f["feature"] for f in feat_rows]
            products.append({
                "id": pid, "store_type": row["store_type"], "name": row["name"],
                "brand": row["brand"], "category": row["category"],
                "price": float(row["price"]),
                "was": float(row["was_price"]) if row["was_price"] is not None else None,
                "rating": float(row["rating"]), "reviews": int(row["reviews"]),
                "img": row["img_url"], "cols": cols, "sizes": sizes, "oos": oos,
                "desc": row["description"], "feats": feats,
                "isNew": bool(row["is_new"]), "width": row["width"],
            })
        return products


# ── User helpers ───────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    salt = os.urandom(16).hex()
    h = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 260000).hex()
    return f"{salt}:{h}"


def verify_password(password: str, stored: str) -> bool:
    try:
        salt, h = stored.split(":", 1)
        check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 260000).hex()
        return check == h
    except Exception:
        return False


def create_user(email: str, password_hash: str, first_name: str, last_name: str) -> dict | None:
    """Insert a new user. Returns the new user dict, or None if email already taken."""
    conn = _get_conn()
    try:
        conn.execute(
            "INSERT INTO users (email, password_hash, first_name, last_name) VALUES (?,?,?,?)",
            (email.strip().lower(), password_hash, first_name.strip(), last_name.strip()),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM users WHERE email = ?", (email.strip().lower(),)).fetchone()
        return _user_dict(row)
    except sqlite3.IntegrityError:
        return None
    finally:
        conn.close()


def get_user_by_email(email: str) -> dict | None:
    conn = _get_conn()
    try:
        row = conn.execute("SELECT * FROM users WHERE email = ?", (email.strip().lower(),)).fetchone()
        return _user_dict(row) if row else None
    finally:
        conn.close()


def get_user_by_id(user_id: int) -> dict | None:
    conn = _get_conn()
    try:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        return _user_dict(row) if row else None
    finally:
        conn.close()


def update_user(user_id: int, first_name: str, last_name: str, phone: str, address: str) -> dict | None:
    conn = _get_conn()
    try:
        conn.execute(
            "UPDATE users SET first_name=?, last_name=?, phone=?, address=? WHERE id=?",
            (first_name, last_name, phone, address, user_id),
        )
        conn.commit()
        return get_user_by_id(user_id)
    finally:
        conn.close()


def _user_dict(row) -> dict:
    return {
        "id": row["id"],
        "email": row["email"],
        "firstName": row["first_name"],
        "lastName": row["last_name"],
        "phone": row["phone"],
        "address": row["address"],
        "passwordHash": row["password_hash"],
    }


# ── Basket helpers ─────────────────────────────────────────────────────────────

def get_basket(user_id: int) -> list[dict]:
    conn = _get_conn()
    try:
        rows = conn.execute(
            "SELECT product_id, size, colour, qty FROM basket_items WHERE user_id = ?",
            (user_id,),
        ).fetchall()
        return [{"product_id": r["product_id"], "size": r["size"], "colour": r["colour"], "qty": r["qty"]} for r in rows]
    finally:
        conn.close()


def upsert_basket_item(user_id: int, product_id: str, size: float, colour: str, qty: int) -> None:
    conn = _get_conn()
    try:
        conn.execute(
            """INSERT INTO basket_items (user_id, product_id, size, colour, qty)
               VALUES (?,?,?,?,?)
               ON CONFLICT(user_id, product_id, size, colour)
               DO UPDATE SET qty = excluded.qty""",
            (user_id, product_id, size, colour, qty),
        )
        conn.commit()
    finally:
        conn.close()


def remove_basket_item(user_id: int, product_id: str, size: float, colour: str) -> None:
    conn = _get_conn()
    try:
        conn.execute(
            "DELETE FROM basket_items WHERE user_id=? AND product_id=? AND size=? AND colour=?",
            (user_id, product_id, size, colour),
        )
        conn.commit()
    finally:
        conn.close()


def clear_basket(user_id: int) -> None:
    conn = _get_conn()
    try:
        conn.execute("DELETE FROM basket_items WHERE user_id=?", (user_id,))
        conn.commit()
    finally:
        conn.close()


# ── Wishlist helpers ───────────────────────────────────────────────────────────

def get_wishlist(user_id: int) -> list[str]:
    conn = _get_conn()
    try:
        rows = conn.execute(
            "SELECT product_id FROM wishlist_items WHERE user_id=?", (user_id,)
        ).fetchall()
        return [r["product_id"] for r in rows]
    finally:
        conn.close()


def add_wishlist(user_id: int, product_id: str) -> None:
    conn = _get_conn()
    try:
        conn.execute(
            "INSERT OR IGNORE INTO wishlist_items (user_id, product_id) VALUES (?,?)",
            (user_id, product_id),
        )
        conn.commit()
    finally:
        conn.close()


def remove_wishlist(user_id: int, product_id: str) -> None:
    conn = _get_conn()
    try:
        conn.execute(
            "DELETE FROM wishlist_items WHERE user_id=? AND product_id=?",
            (user_id, product_id),
        )
        conn.commit()
    finally:
        conn.close()


# ── Order helpers ──────────────────────────────────────────────────────────────

def _build_order_dict(conn: sqlite3.Connection, order_row) -> dict:
    oid = order_row["id"]
    steps = conn.execute(
        "SELECT label, date_text, done, active FROM order_steps WHERE order_id=? ORDER BY sort_order",
        (oid,),
    ).fetchall()
    items = conn.execute(
        "SELECT product_id, qty, size, colour FROM order_items WHERE order_id=?",
        (oid,),
    ).fetchall()
    return {
        "id": oid,
        "status": order_row["status"],
        "statusCls": order_row["status_cls"],
        "createdAt": order_row["created_at"],
        "steps": [{"l": s["label"], "d": s["date_text"], "done": bool(s["done"]), "active": bool(s["active"])} for s in steps],
        "items": [{"id": i["product_id"], "qty": i["qty"], "sz": i["size"], "col": i["colour"]} for i in items],
    }


def get_orders_for_user(user_id: int) -> list[dict]:
    conn = _get_conn()
    try:
        rows = conn.execute(
            "SELECT * FROM orders WHERE user_id=? ORDER BY created_at DESC", (user_id,)
        ).fetchall()
        return [_build_order_dict(conn, r) for r in rows]
    finally:
        conn.close()


def get_order_by_number(order_num: str) -> dict | None:
    conn = _get_conn()
    try:
        row = conn.execute("SELECT * FROM orders WHERE id=?", (order_num.upper(),)).fetchone()
        if not row:
            return None
        return _build_order_dict(conn, row)
    finally:
        conn.close()


def place_order(user_id: int, delivery_label: str) -> str:
    """Create an order from the user's current basket, clear basket, return order number."""
    conn = _get_conn()
    try:
        basket = conn.execute(
            "SELECT product_id, size, colour, qty FROM basket_items WHERE user_id=?", (user_id,)
        ).fetchall()
        if not basket:
            raise ValueError("Basket is empty")

        order_num = f"CLK-{random.randint(29000, 99000)}"
        # Ensure unique
        while conn.execute("SELECT id FROM orders WHERE id=?", (order_num,)).fetchone():
            order_num = f"CLK-{random.randint(29000, 99000)}"

        now = datetime.now()
        conn.execute(
            "INSERT INTO orders (id, user_id, status, status_cls) VALUES (?,?,?,?)",
            (order_num, user_id, "Processing", "ts-processing"),
        )
        for item in basket:
            conn.execute(
                "INSERT INTO order_items (order_id, product_id, qty, size, colour) VALUES (?,?,?,?,?)",
                (order_num, item["product_id"], item["qty"], item["size"], item["colour"]),
            )
        steps = [
            ("Order Placed",       now.strftime("%a %d %b, %H:%M"), 1, 1),
            ("Payment Confirmed",  now.strftime("%a %d %b, %H:%M"), 1, 0),
            ("Picking & Packing",  "Pending",                        0, 0),
            ("Dispatched",         f"Estimated {(now + timedelta(days=1)).strftime('%a %d %b')}", 0, 0),
            ("Out for Delivery",   f"Estimated {(now + timedelta(days=2)).strftime('%a %d %b')}", 0, 0),
            ("Delivered",          f"Estimated {(now + timedelta(days=3)).strftime('%a %d %b')}", 0, 0),
        ]
        for sort_i, (label, date_text, done, active) in enumerate(steps):
            conn.execute(
                "INSERT INTO order_steps (order_id, label, date_text, done, active, sort_order) VALUES (?,?,?,?,?,?)",
                (order_num, label, date_text, done, active, sort_i),
            )
        conn.execute("DELETE FROM basket_items WHERE user_id=?", (user_id,))
        conn.commit()
        return order_num
    finally:
        conn.close()


def generate_new_user_orders(user_id: int) -> None:
    """Generate 2–3 realistic historical orders for a brand-new account."""
    conn = _get_conn()
    try:
        all_product_ids = [r[0] for r in conn.execute("SELECT id FROM products").fetchall()]
        if not all_product_ids:
            return

        now = datetime.now()

        # Template stages: (status, status_cls, steps_done_count, has_active_on_step)
        # steps_done_count = how many of the 6 steps are done; active is put on the last done step
        templates = [
            ("Delivered",        "ts-delivered",   6, 5),  # all done, active=last
            ("Out for Delivery",  "ts-transit",     5, 4),
            ("Processing",        "ts-processing",  2, 1),
        ]

        step_labels = [
            "Order Placed",
            "Payment Confirmed",
            "Picking & Packing",
            "Dispatched",
            "Out for Delivery",
            "Delivered",
        ]

        num_orders = random.randint(2, 3)
        chosen_templates = random.sample(templates, num_orders)

        for t_idx, (status, status_cls, done_count, active_idx) in enumerate(chosen_templates):
            order_num = f"CLK-{random.randint(29000, 99000)}"
            while conn.execute("SELECT id FROM orders WHERE id=?", (order_num,)).fetchone():
                order_num = f"CLK-{random.randint(29000, 99000)}"

            days_ago = (num_orders - t_idx) * random.randint(7, 21)
            order_date = now - timedelta(days=days_ago)

            conn.execute(
                "INSERT INTO orders (id, user_id, status, status_cls, created_at) VALUES (?,?,?,?,?)",
                (order_num, user_id, status, status_cls, order_date.strftime("%Y-%m-%d %H:%M:%S")),
            )

            # 1 or 2 products per order
            chosen_pids = random.sample(all_product_ids, min(random.randint(1, 2), len(all_product_ids)))
            for pid in chosen_pids:
                # pick a plausible size
                size_row = conn.execute(
                    "SELECT size FROM product_sizes WHERE product_id=? ORDER BY RANDOM() LIMIT 1", (pid,)
                ).fetchone()
                size = float(size_row["size"]) if size_row else 9.0
                # pick a colour
                col_row = conn.execute(
                    "SELECT colour_name FROM product_colours WHERE product_id=? ORDER BY RANDOM() LIMIT 1", (pid,)
                ).fetchone()
                colour = col_row["colour_name"] if col_row else "Black"
                conn.execute(
                    "INSERT INTO order_items (order_id, product_id, qty, size, colour) VALUES (?,?,?,?,?)",
                    (order_num, pid, 1, size, colour),
                )

            # Build steps
            for sort_i, label in enumerate(step_labels):
                done = 1 if sort_i < done_count else 0
                active = 1 if sort_i == active_idx else 0
                if sort_i < done_count:
                    step_date = (order_date + timedelta(hours=sort_i * 8)).strftime("%a %d %b, %H:%M")
                elif sort_i == done_count:
                    step_date = f"Estimated {(now + timedelta(days=1)).strftime('%a %d %b')}"
                else:
                    step_date = f"Estimated {(now + timedelta(days=sort_i - done_count + 1)).strftime('%a %d %b')}"
                conn.execute(
                    "INSERT INTO order_steps (order_id, label, date_text, done, active, sort_order) VALUES (?,?,?,?,?,?)",
                    (order_num, label, step_date, done, active, sort_i),
                )

        conn.commit()
    finally:
        conn.close()


# ── Store helpers ──────────────────────────────────────────────────────────────

def get_stores(q: str | None = None) -> list[dict]:
    conn = _get_conn()
    try:
        if q and q.strip():
            pattern = f"%{q.strip()}%"
            rows = conn.execute(
                "SELECT * FROM stores WHERE name LIKE ? OR address LIKE ?", (pattern, pattern)
            ).fetchall()
        else:
            rows = conn.execute("SELECT * FROM stores").fetchall()
        return [
            {
                "name":      r["name"],
                "type":      r["type"],
                "typeLbl":   r["type_label"],
                "typeClass": r["type_class"],
                "addr":      r["address"],
                "hours":     r["hours"],
                "phone":     r["phone"],
            }
            for r in rows
        ]
    finally:
        conn.close()
