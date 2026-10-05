import enum
from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Enum, ForeignKey
from sqlalchemy.sql import func
from app.database import Base

class UserRole(str, enum.Enum):
    CUSTOMER = "CUSTOMER"
    KITCHEN = "KITCHEN"
    ADMIN = "ADMIN"

class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, index=True, nullable=False)
    mobile = Column(String(15), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.CUSTOMER, nullable=False)
    
    # Kitchen staff scoping: MUST be attached to a specific canteen
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="SET NULL"), nullable=True)
    
    profile_image_url = Column(String(500), nullable=True)
    fcm_token = Column(String(255), nullable=True)  # Background OS push notifications
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
