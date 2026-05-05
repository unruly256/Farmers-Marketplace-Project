from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Date
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    national_id = Column(String, unique=True, nullable=True) # Nullable for buyers
    role = Column(String, nullable=False) # 'farmer' or 'buyer'
    password_hash = Column(String, nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    produce_listings = relationship("Produce", back_populates="farmer")
    orders_placed = relationship("Order", back_populates="buyer")

class Produce(Base):
    __tablename__ = "produce"

    produce_id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    crop_type = Column(String, nullable=False)
    quantity = Column(Float, nullable=False) # kg or bunches
    price = Column(Float, nullable=False) # UGX
    location = Column(String, nullable=True)
    harvest_date = Column(Date, nullable=True)

    # Relationships
    farmer = relationship("User", back_populates="produce_listings")
    orders = relationship("Order", back_populates="produce")

class Order(Base):
    __tablename__ = "orders"

    order_id = Column(Integer, primary_key=True, index=True)
    buyer_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    produce_id = Column(Integer, ForeignKey("produce.produce_id"), nullable=False)
    status = Column(String, default="Pending") # Pending, Accepted, Rejected, Completed
    timestamp = Column(DateTime, default=datetime.utcnow)
    total_amount = Column(Float, nullable=False)

    # Relationships
    buyer = relationship("User", back_populates="orders_placed")
    produce = relationship("Produce", back_populates="orders")

# --- NEW: CHAT MESSAGES ---
class Message(Base):
    __tablename__ = "messages"

    message_id = Column(Integer, primary_key=True, index=True)
    sender_phone = Column(String, nullable=False)
    receiver_phone = Column(String, nullable=False)
    content = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)