import enum
from sqlalchemy import Column, Integer, BigInteger, Numeric, ForeignKey, String, Text, DateTime, Enum, CheckConstraint
from sqlalchemy.sql import func
from app.database import Base

class TransactionType(str, enum.Enum):
    CREDIT = "CREDIT"
    DEBIT = "DEBIT"
    REFUND = "REFUND"
    ADJUSTMENT = "ADJUSTMENT"

class Wallet(Base):
    __tablename__ = "wallets"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    balance = Column(Numeric(12, 2), default=0.00, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        CheckConstraint("balance >= 0.00", name="chk_wallet_positive_balance"),
    )

class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True)
    wallet_id = Column(BigInteger, ForeignKey("wallets.id", ondelete="RESTRICT"), nullable=False, index=True)
    transaction_type = Column(Enum(TransactionType), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    balance_before = Column(Numeric(12, 2), nullable=False)
    balance_after = Column(Numeric(12, 2), nullable=False)
    reference_type = Column(String(50), nullable=False)  # 'ORDER_PAYMENT', 'ORDER_REFUND', 'ADMIN_CREDIT'
    reference_id = Column(String(100), nullable=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint("amount > 0.00", name="chk_tx_positive_amount"),
    )
