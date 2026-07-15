"""
main.py — Clerks Footwear FastAPI backend

Run with:
    uvicorn main:app --reload

Then open: http://127.0.0.1:8000
"""
import uuid
from typing import Optional

from fastapi import FastAPI, Query, Request, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from contextlib import asynccontextmanager

import database as db


# ── In-memory session store ────────────────────────────────────────────────────
# Maps token (str UUID) → user_id (int)
# Cleared when the server restarts — intentional (accounts persist in the DB).
SESSIONS: dict[str, int] = {}


# ── Auth helpers ───────────────────────────────────────────────────────────────

def require_auth(request: Request) -> int:
    """Read Bearer token from Authorization header, return user_id or raise 401."""
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    token = auth[7:]
    user_id = SESSIONS.get(token)
    if user_id is None:
        raise HTTPException(status_code=401, detail="Session expired — please sign in again")
    return user_id


def _make_token(user_id: int) -> str:
    token = str(uuid.uuid4())
    SESSIONS[token] = user_id
    return token


def _public_user(user: dict) -> dict:
    """Strip the password hash before sending to the client."""
    return {k: v for k, v in user.items() if k != "passwordHash"}


# ── Startup ────────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init_db()
    yield


app = FastAPI(title="Clerks Footwear API", lifespan=lifespan)


# ── Pydantic models ────────────────────────────────────────────────────────────

class RegisterBody(BaseModel):
    email: str
    password: str
    first_name: str
    last_name: str = ""

class SignInBody(BaseModel):
    email: str
    password: str

class SignOutBody(BaseModel):
    token: str

class BasketItemBody(BaseModel):
    product_id: str
    size: float
    colour: str
    qty: int = 1

class BasketRemoveBody(BaseModel):
    size: float
    colour: str

class PlaceOrderBody(BaseModel):
    delivery_label: str = "Standard Delivery (3–5 days)"

class UpdateProfileBody(BaseModel):
    first_name: str
    last_name: str = ""
    phone: str = ""
    address: str = ""


# ── Products ───────────────────────────────────────────────────────────────────

@app.get("/api/products")
async def get_products(store_type: Optional[str] = Query(default=None)):
    return await db.fetch_products(store_type=store_type)


@app.get("/api/products/search")
async def search_products(
    q:          Optional[str]   = Query(default=None, description="Free-text search across name, brand, category, description, features"),
    store_type: Optional[str]   = Query(default=None, description="'sports' or 'formal'"),
    category:   Optional[str]   = Query(default=None, description="e.g. Running, Oxford Shoes"),
    brand:      Optional[str]   = Query(default=None, description="Partial brand name match"),
    min_price:  Optional[float] = Query(default=None, description="Minimum price (£)"),
    max_price:  Optional[float] = Query(default=None, description="Maximum price (£)"),
    on_sale:    bool             = Query(default=False, description="Only return discounted products"),
    colour:     Optional[str]   = Query(default=None, description="Colour name substring match"),
    width:      Optional[str]   = Query(default=None, description="Standard, Wide, Extra Wide"),
    sort:       str              = Query(default="featured", description="featured|price-asc|price-desc|rating|discount|reviews"),
    limit:      int              = Query(default=20, ge=1, le=50, description="Max results (1-50)"),
):
    """Search and filter products from the database. Used by the AI chatbot."""
    return await db.search_products(
        q=q, store_type=store_type, category=category, brand=brand,
        min_price=min_price, max_price=max_price, on_sale=on_sale,
        colour=colour, width=width, sort=sort, limit=limit,
    )


# ── Auth ───────────────────────────────────────────────────────────────────────

@app.post("/api/register")
async def register(body: RegisterBody):
    email = body.email.strip().lower()
    if not email or not body.password:
        return {"ok": False, "error": "Email and password are required"}
    if len(body.password) < 8:
        return {"ok": False, "error": "Password must be at least 8 characters"}
    if not body.first_name.strip():
        return {"ok": False, "error": "First name is required"}

    password_hash = db.hash_password(body.password)
    user = db.create_user(email, password_hash, body.first_name, body.last_name)
    if user is None:
        return {"ok": False, "error": "An account with that email already exists"}

    # Generate random historical orders for this new account (one-time)
    db.generate_new_user_orders(user["id"])

    token = _make_token(user["id"])
    return {"ok": True, "token": token, "user": _public_user(user)}


@app.post("/api/signin")
async def signin(body: SignInBody):
    email = body.email.strip().lower()
    user = db.get_user_by_email(email)
    if user is None or not db.verify_password(body.password, user["passwordHash"]):
        return {"ok": False, "error": "Invalid email or password"}
    token = _make_token(user["id"])
    return {"ok": True, "token": token, "user": _public_user(user)}


@app.post("/api/signout")
async def signout(body: SignOutBody):
    SESSIONS.pop(body.token, None)
    return {"ok": True}


@app.get("/api/me")
async def me(request: Request):
    user_id = require_auth(request)
    user = db.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _public_user(user)


@app.post("/api/me/update")
async def update_profile(request: Request, body: UpdateProfileBody):
    user_id = require_auth(request)
    user = db.update_user(user_id, body.first_name, body.last_name, body.phone, body.address)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"ok": True, "user": _public_user(user)}


# ── Basket ─────────────────────────────────────────────────────────────────────

@app.get("/api/basket")
async def get_basket(request: Request):
    user_id = require_auth(request)
    return db.get_basket(user_id)


@app.post("/api/basket")
async def add_basket(request: Request, body: BasketItemBody):
    user_id = require_auth(request)
    db.upsert_basket_item(user_id, body.product_id, body.size, body.colour, body.qty)
    return {"ok": True}


@app.delete("/api/basket/{product_id}")
async def remove_basket(request: Request, product_id: str, body: BasketRemoveBody):
    user_id = require_auth(request)
    db.remove_basket_item(user_id, product_id, body.size, body.colour)
    return {"ok": True}


@app.post("/api/basket/clear")
async def clear_basket(request: Request):
    user_id = require_auth(request)
    db.clear_basket(user_id)
    return {"ok": True}


# ── Wishlist ───────────────────────────────────────────────────────────────────

@app.get("/api/wishlist")
async def get_wishlist(request: Request):
    user_id = require_auth(request)
    return db.get_wishlist(user_id)


@app.post("/api/wishlist/{product_id}")
async def add_wishlist(request: Request, product_id: str):
    user_id = require_auth(request)
    db.add_wishlist(user_id, product_id)
    return {"ok": True}


@app.delete("/api/wishlist/{product_id}")
async def remove_wishlist(request: Request, product_id: str):
    user_id = require_auth(request)
    db.remove_wishlist(user_id, product_id)
    return {"ok": True}


# ── Orders ─────────────────────────────────────────────────────────────────────

@app.get("/api/orders")
async def get_orders(request: Request):
    user_id = require_auth(request)
    return db.get_orders_for_user(user_id)


@app.get("/api/track/{order_num}")
async def track_order(order_num: str):
    order = db.get_order_by_number(order_num)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@app.post("/api/orders/place")
async def place_order(request: Request, body: PlaceOrderBody):
    user_id = require_auth(request)
    try:
        order_num = db.place_order(user_id, body.delivery_label)
        return {"ok": True, "orderNum": order_num}
    except ValueError as e:
        return {"ok": False, "error": str(e)}


# ── Stores ─────────────────────────────────────────────────────────────────────

@app.get("/api/stores")
async def get_stores(q: Optional[str] = Query(default=None)):
    return db.get_stores(q)


# ── Serve index.html at the root ───────────────────────────────────────────────

@app.get("/")
async def root():
    return FileResponse("index.html")
