from sqlalchemy import Column, Integer, BigInteger, String, Numeric, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.sql import func
from app.database import Base

class Inventory(Base):
    __tablename__ = "inventory"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="CASCADE"), nullable=False, index=True)
    item_name = Column(String(100), nullable=False)
    unit = Column(String(20), nullable=False)  # 'kg', 'packets', 'liters'
    current_quantity = Column(Numeric(10, 2), nullable=False)
    reorder_level = Column(Numeric(10, 2), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("canteen_id", "item_name", name="uq_canteen_inventory_item"),
    )
