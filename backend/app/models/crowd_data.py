from sqlalchemy import Column, BigInteger, Integer, Numeric, ForeignKey, String, DateTime
from sqlalchemy.sql import func
from app.database import Base

class CrowdData(Base):
    __tablename__ = "crowd_data"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    canteen_id = Column(BigInteger, ForeignKey("canteens.id", ondelete="CASCADE"), nullable=False, index=True)
    people_count = Column(Integer, nullable=False)
    active_orders = Column(Integer, nullable=False)
    average_wait_time = Column(Numeric(5, 2), nullable=False)
    crowd_score = Column(Numeric(5, 2), nullable=False)
    crowd_level = Column(String(30), nullable=False)
    recorded_at = Column(DateTime(timezone=True), server_default=func.now())
