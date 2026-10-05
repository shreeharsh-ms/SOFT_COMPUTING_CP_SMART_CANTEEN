from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from app.models.wallet import TransactionType

class WalletTransactionResponse(BaseModel):
    id: int
    transaction_type: TransactionType
    amount: float
    balance_before: float
    balance_after: float
    reference_type: str
    reference_id: Optional[str] = None
    description: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class WalletResponse(BaseModel):
    wallet_id: int
    user_id: int
    balance: float
    recent_transactions: List[WalletTransactionResponse] = []

class AdminCreditRequest(BaseModel):
    target_user_id: int
    token_amount: float = Field(..., gt=0.0)
    notes: Optional[str] = "Admin counter deposit top-up"

class CustomerTopUpRequest(BaseModel):
    token_amount: float = Field(..., gt=0.0)
    payment_method: Optional[str] = "UPI / NetBanking"
