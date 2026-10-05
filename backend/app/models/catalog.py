from sqlalchemy import Column, BigInteger, String, Text, Numeric, Integer, Boolean, ForeignKey, DateTime, UniqueConstraint, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Category(Base):
    __tablename__ = "categories"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    image_url = Column(String(500), nullable=True)
    display_order = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    items = relationship("MenuItem", back_populates="category", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("canteen_id", "name", name="uq_canteen_category"),
    )

class MenuItem(Base):
    __tablename__ = "menu_items"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(BigInteger, ForeignKey("categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Numeric(8, 2), nullable=False)  # Gross tax-inclusive price charged to student
    original_price = Column(Numeric(8, 2), nullable=False)
    
    # Statutory GST Tax Classification & Rates
    hsn_sac_code = Column(String(10), nullable=False, default="996331")  # SAC 996331: Restaurant/canteen service
    gst_rate_percent = Column(Numeric(4, 2), nullable=False, default=5.00)  # Standard 5.00% GST without ITC
    
    # Explicit physical stock quantity quota
    stock_quantity = Column(Integer, nullable=True)  # None = Unlimited / Cook-to-order
    
    preparation_time_minutes = Column(Integer, default=10, nullable=False)
    is_available = Column(Boolean, default=True, nullable=False)
    is_recommended = Column(Boolean, default=False, nullable=False)
    image_url = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    category = relationship("Category", back_populates="items")

    __table_args__ = (
        CheckConstraint("price >= 0.00", name="chk_menu_positive_price"),
        CheckConstraint("stock_quantity IS NULL OR stock_quantity >= 0", name="chk_menu_stock_positive"),
    )
