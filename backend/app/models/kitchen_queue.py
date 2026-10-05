from sqlalchemy import Column, BigInteger, Integer, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base

class KitchenQueue(Base):
    __tablename__ = "kitchen_queue"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="CASCADE"), nullable=False, index=True)
    order_id = Column(BigInteger, ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    recommended_position = Column(Integer, nullable=False)
    estimated_prep_time_minutes = Column(Numeric(6, 2), nullable=False)
    cumulative_wait_minutes = Column(Numeric(6, 2), nullable=False)
    optimization_run_at = Column(DateTime(timezone=True), server_default=func.now())
