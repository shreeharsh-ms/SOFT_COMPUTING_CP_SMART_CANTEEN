import enum
from sqlalchemy import Column, BigInteger, String, Text, Numeric, Integer, Boolean, ForeignKey, DateTime, Enum, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class OrderType(str, enum.Enum):
    IMMEDIATE = "IMMEDIATE"
    SCHEDULED = "SCHEDULED"

class OrderStatus(str, enum.Enum):
    PLACED = "PLACED"
    CONFIRMED = "CONFIRMED"
    PREPARING = "PREPARING"
    READY = "READY"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

class Order(Base):
    __tablename__ = "orders"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    order_number = Column(String(30), unique=True, index=True, nullable=False)
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="RESTRICT"), nullable=False, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    order_type = Column(Enum(OrderType), default=OrderType.IMMEDIATE, nullable=False)
    status = Column(Enum(OrderStatus), default=OrderStatus.PLACED, nullable=False, index=True)
    scheduled_at = Column(DateTime(timezone=True), nullable=True)
    
    # Statutory Tax Invoicing & Decomposition Breakdown
    invoice_number = Column(String(30), unique=True, index=True, nullable=True)  # Sequential FY tax invoice ID
    tax_inclusive_pricing = Column(Boolean, default=True, nullable=False)  # Audit trail indicator
    subtotal_taxable_value = Column(Numeric(10, 2), nullable=False, default=0.00)  # Total taxable net value
    total_cgst_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # Central GST (intra-state)
    total_sgst_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # State GST (intra-state)
    total_igst_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # Integrated GST (inter-state)
    total_tax_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # Total tax sum
    total_amount = Column(Numeric(10, 2), nullable=False)  # Grand total debited from wallet
    payment_status = Column(String(20), default="PAID", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    canteen = relationship("Canteen", lazy="selectin")
    history = relationship("OrderStatusHistory", back_populates="order", cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint("total_amount >= 0.00", name="chk_order_positive_amount"),
    )

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    order_id = Column(BigInteger, ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    menu_item_id = Column(BigInteger, ForeignKey("menu_items.id", ondelete="RESTRICT"), nullable=False)
    item_name = Column(String(120), nullable=False)
    unit_price = Column(Numeric(8, 2), nullable=False)
    quantity = Column(Integer, nullable=False)
    total_price = Column(Numeric(10, 2), nullable=False)

    # Point-in-time statutory snapshot (immutable audit record)
    hsn_sac_code = Column(String(10), nullable=False, default="996331")
    gst_rate_percent = Column(Numeric(4, 2), nullable=False, default=5.00)
    taxable_value = Column(Numeric(10, 2), nullable=False, default=0.00)  # Line net taxable value
    cgst_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # Central GST component
    sgst_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # State GST component
    igst_amount = Column(Numeric(10, 2), nullable=False, default=0.00)  # Integrated GST component

    order = relationship("Order", back_populates="items")

    __table_args__ = (
        CheckConstraint("quantity > 0", name="chk_order_item_positive_qty"),
    )

class OrderStatusHistory(Base):
    __tablename__ = "order_status_history"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    order_id = Column(BigInteger, ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(Enum(OrderStatus), nullable=False)
    changed_by_user_id = Column(BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    order = relationship("Order", back_populates="history")
