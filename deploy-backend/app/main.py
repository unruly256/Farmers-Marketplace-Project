from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from pydantic import BaseModel
from typing import Optional
from datetime import date
import bcrypt
import os
import shutil

from app import models
from app.database import engine, SessionLocal

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Farmers Marketplace API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads/profile_pictures"
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs("uploads", exist_ok=True)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class UserCreate(BaseModel):
    full_name: str
    email: Optional[str] = None
    phone: str
    national_id: Optional[str] = ""
    password: str
    role: str


class UserLogin(BaseModel):
    phone: str
    password: str


class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    location: Optional[str] = None


class ProduceCreate(BaseModel):
    farmer_phone: str
    crop_type: str
    quantity: float
    price: float


class CartItemSchema(BaseModel):
    produce_id: int
    total_amount: float


class OrderCreate(BaseModel):
    buyer_phone: str
    items: list[CartItemSchema]


class OrderStatusUpdate(BaseModel):
    status: str
    farmer_phone: str


class MessageCreate(BaseModel):
    sender_phone: str
    receiver_phone: str
    content: str


@app.post("/api/users/register")
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(
        models.User.phone_number == user.phone
    ).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    hashed_pw = bcrypt.hashpw(
        user.password.encode("utf-8"),
        bcrypt.gensalt()
    ).decode("utf-8")

    db_user = models.User(
        full_name=user.full_name,
        phone_number=user.phone,
        national_id=user.national_id if user.role == "farmer" else None,
        role=user.role,
        password_hash=hashed_pw,
        location=None,
        profile_url=None,
    )

    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    return {
        "status": "success",
        "message": f"{user.role.capitalize()} account created successfully!"
    }


@app.post("/api/users/login")
def login_user(login_data: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(
        models.User.phone_number == login_data.phone
    ).first()
    if not db_user:
        raise HTTPException(status_code=400, detail="Invalid phone number or password.")

    valid_password = bcrypt.checkpw(
        login_data.password.encode("utf-8"),
        db_user.password_hash.encode("utf-8")
    )
    if not valid_password:
        raise HTTPException(status_code=400, detail="Invalid phone number or password.")

    return {
        "status": "success",
        "message": f"Welcome back, {db_user.full_name}!",
        "role": db_user.role,
        "name": db_user.full_name
    }


@app.get("/api/users/{phone}")
def get_user_profile(phone: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    return {
        "status": "success",
        "data": {
            "full_name": user.full_name,
            "phone": user.phone_number,
            "role": user.role,
            "location": user.location,
            "profile_url": user.profile_url,
        }
    }


@app.patch("/api/users/{phone}")
def update_user_profile(phone: str, payload: UserProfileUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()

    if payload.location is not None:
        user.location = payload.location.strip()

    db.add(user)
    db.commit()
    db.refresh(user)

    return {
        "status": "success",
        "message": "Profile updated successfully.",
        "data": {
            "full_name": user.full_name,
            "phone": user.phone_number,
            "role": user.role,
            "location": user.location,
            "profile_url": user.profile_url,
        }
    }


@app.post("/api/users/{phone}/profile-picture")
def upload_profile_picture(
    phone: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    if not file.filename:
        raise HTTPException(status_code=400, detail="No file selected.")

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(status_code=400, detail="Unsupported image format.")

    safe_filename = f"{phone}{ext}"
    save_path = os.path.join(UPLOAD_DIR, safe_filename)

    with open(save_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    user.profile_url = f"http://127.0.0.1:8000/uploads/profile_pictures/{safe_filename}"

    db.add(user)
    db.commit()
    db.refresh(user)

    return {
        "status": "success",
        "message": "Profile picture uploaded successfully.",
        "data": {
            "full_name": user.full_name,
            "phone": user.phone_number,
            "role": user.role,
            "location": user.location,
            "profile_url": user.profile_url,
        }
    }


@app.post("/api/produce/add")
def add_produce(produce: ProduceCreate, db: Session = Depends(get_db)):
    farmer = db.query(models.User).filter(
        models.User.phone_number == produce.farmer_phone
    ).first()
    if not farmer or farmer.role != "farmer":
        raise HTTPException(status_code=403, detail="Only registered farmers can list produce.")

    new_produce = models.Produce(
        farmer_id=farmer.user_id,
        crop_type=produce.crop_type,
        quantity=produce.quantity,
        price=produce.price,
        harvest_date=date.today()
    )

    db.add(new_produce)
    db.commit()
    db.refresh(new_produce)

    return {
        "status": "success",
        "message": f"{produce.crop_type} listed successfully!"
    }


@app.get("/api/produce")
def get_all_produce(db: Session = Depends(get_db)):
    results = (
        db.query(models.Produce, models.User.full_name, models.User.phone_number)
        .join(models.User, models.Produce.farmer_id == models.User.user_id)
        .all()
    )

    produce_list = []
    for produce, farmer_name, farmer_phone in results:
        produce_list.append({
            "id": produce.produce_id,
            "name": produce.crop_type,
            "farmer": farmer_name,
            "farmer_phone": farmer_phone,
            "price": str(int(produce.price)),
            "quantity": produce.quantity
        })

    return {"status": "success", "data": produce_list}


@app.post("/api/orders/create")
def create_order(order_data: OrderCreate, db: Session = Depends(get_db)):
    buyer = db.query(models.User).filter(
        models.User.phone_number == order_data.buyer_phone
    ).first()

    if not buyer:
        raise HTTPException(status_code=400, detail="Buyer account not found.")

    for item in order_data.items:
        produce = db.query(models.Produce).filter(
            models.Produce.produce_id == item.produce_id
        ).first()

        if not produce:
            raise HTTPException(
                status_code=404,
                detail=f"Produce item #{item.produce_id} no longer exists."
            )

        if produce.price <= 0:
            raise HTTPException(
                status_code=400,
                detail=f"{produce.crop_type} has an invalid price. Contact the farmer."
            )

        qty_requested = item.total_amount / produce.price

        if qty_requested > produce.quantity:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Not enough stock! You requested {qty_requested:.1f} kg of "
                    f"{produce.crop_type}, but only {produce.quantity:.1f} kg is available."
                )
            )

        new_order = models.Order(
            buyer_id=buyer.user_id,
            produce_id=item.produce_id,
            total_amount=item.total_amount,
            status="Pending"
        )
        db.add(new_order)

    db.commit()

    return {
        "status": "success",
        "message": "Order placed successfully! The farmer will be notified."
    }


@app.get("/api/orders/farmer/{farmer_phone}")
def get_farmer_orders(farmer_phone: str, db: Session = Depends(get_db)):
    farmer = db.query(models.User).filter(
        models.User.phone_number == farmer_phone
    ).first()

    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer not found.")
    if farmer.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can access this.")

    results = (
        db.query(models.Order, models.Produce, models.User)
        .join(models.Produce, models.Order.produce_id == models.Produce.produce_id)
        .join(models.User, models.Order.buyer_id == models.User.user_id)
        .filter(models.Produce.farmer_id == farmer.user_id)
        .order_by(models.Order.timestamp.desc())
        .all()
    )

    orders_list = []
    for order, produce, buyer in results:
        qty_ordered = (order.total_amount / produce.price) if produce.price > 0 else 0

        orders_list.append({
            "order_id": order.order_id,
            "buyer_name": buyer.full_name,
            "buyer_phone": buyer.phone_number,
            "crop_name": produce.crop_type,
            "quantity_ordered": round(qty_ordered, 1),
            "total_amount": order.total_amount,
            "status": order.status,
            "timestamp": order.timestamp.strftime("%d %b %Y, %H:%M"),
        })

    return {"status": "success", "data": orders_list}


@app.patch("/api/orders/{order_id}/status")
def update_order_status(order_id: int, update: OrderStatusUpdate, db: Session = Depends(get_db)):
    valid_statuses = {"Accepted", "Rejected"}
    if update.status not in valid_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status. Must be one of: {valid_statuses}"
        )

    order = db.query(models.Order).filter(models.Order.order_id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")

    if order.status != "Pending":
        raise HTTPException(
            status_code=400,
            detail=f"This order is already '{order.status}' and cannot be changed."
        )

    produce = db.query(models.Produce).filter(models.Produce.produce_id == order.produce_id).first()
    farmer = db.query(models.User).filter(models.User.phone_number == update.farmer_phone).first()

    if not farmer or not produce or produce.farmer_id != farmer.user_id:
        raise HTTPException(
            status_code=403,
            detail="You can only manage orders for your own produce."
        )

    order.status = update.status
    db.add(order)

    if update.status == "Accepted" and produce.price > 0:
        qty_ordered = order.total_amount / produce.price
        produce.quantity = max(0.0, produce.quantity - qty_ordered)
        db.add(produce)

    db.commit()
    db.refresh(order)
    db.refresh(produce)

    action_word = "accepted" if update.status == "Accepted" else "rejected"
    return {
        "status": "success",
        "message": f"Order {action_word} successfully!",
        "debug": {
            "new_order_status": order.status,
            "remaining_stock": produce.quantity,
        }
    }


@app.post("/api/messages/send")
def send_message(msg: MessageCreate, db: Session = Depends(get_db)):
    new_msg = models.Message(
        sender_phone=msg.sender_phone,
        receiver_phone=msg.receiver_phone,
        content=msg.content
    )
    db.add(new_msg)
    db.commit()
    return {"status": "success"}


@app.get("/api/messages/{user1_phone}/{user2_phone}")
def get_messages(user1_phone: str, user2_phone: str, db: Session = Depends(get_db)):
    messages = db.query(models.Message).filter(
        or_(
            and_(models.Message.sender_phone == user1_phone, models.Message.receiver_phone == user2_phone),
            and_(models.Message.sender_phone == user2_phone, models.Message.receiver_phone == user1_phone)
        )
    ).order_by(models.Message.timestamp.asc()).all()

    chat_history = [
        {"sender": m.sender_phone, "content": m.content, "time": m.timestamp.strftime("%H:%M")}
        for m in messages
    ]

    return {"status": "success", "data": chat_history}
