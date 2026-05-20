from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Date
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    national_id = Column(String, unique=True, nullable=True)
    role = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    location = Column(String, nullable=True)
    profile_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    produce_listings = relationship("Produce", back_populates="farmer")
    orders_placed = relationship("Order", back_populates="buyer")

class Produce(Base):
    __tablename__ = "produce"

    produce_id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    crop_type = Column(String, nullable=False)
    quantity = Column(Float, nullable=False)
    price = Column(Float, nullable=False)
    location = Column(String, nullable=True)
    harvest_date = Column(Date, nullable=True)

    farmer = relationship("User", back_populates="produce_listings")
    orders = relationship("Order", back_populates="produce")

class Order(Base):
    __tablename__ = "orders"

    order_id = Column(Integer, primary_key=True, index=True)
    buyer_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    produce_id = Column(Integer, ForeignKey("produce.produce_id"), nullable=False)
    status = Column(String, default="Pending")
    timestamp = Column(DateTime, default=datetime.utcnow)
    total_amount = Column(Float, nullable=False)

    buyer = relationship("User", back_populates="orders_placed")
    produce = relationship("Produce", back_populates="orders")

class Message(Base):
    __tablename__ = "messages"

    message_id = Column(Integer, primary_key=True, index=True)
    sender_phone = Column(String, nullable=False)
    receiver_phone = Column(String, nullable=False)
    content = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
