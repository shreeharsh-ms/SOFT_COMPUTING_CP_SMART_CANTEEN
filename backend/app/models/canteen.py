from sqlalchemy import Column, Integer, BigInteger, String, Text, Time, Boolean, DateTime
from sqlalchemy.sql import func
from app.database import Base

class Canteen(Base):
    __tablename__ = "canteens"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    legal_name = Column(String(200), nullable=True)  # Official registered entity name for tax invoices
    gstin = Column(String(15), nullable=True, index=True)  # 15-character GSTIN, e.g., '27ABCDE1234F1Z5'
    registered_address = Column(Text, nullable=True)  # Tax invoice billing address
    description = Column(Text, nullable=True)
    location = Column(String(200), nullable=False)
    image_url = Column(String(500), nullable=True)
    opening_time = Column(Time, nullable=False)
    closing_time = Column(Time, nullable=False)
    is_open = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
