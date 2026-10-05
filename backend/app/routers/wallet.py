from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from decimal import Decimal
from app.database import get_db
from app.models.user import User, UserRole
from app.models.wallet import Wallet, WalletTransaction
from app.schemas.wallet import WalletResponse, WalletTransactionResponse, AdminCreditRequest, CustomerTopUpRequest
from app.services.wallet_service import WalletService
from app.core.deps import get_current_user, require_role

router = APIRouter(prefix="/wallet", tags=["Wallet"])

@router.get("", response_model=WalletResponse)
async def get_my_wallet(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Wallet).where(Wallet.user_id == current_user.id)
    wallet = (await db.execute(stmt)).scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    tx_stmt = select(WalletTransaction).where(
        WalletTransaction.wallet_id == wallet.id
    ).order_by(WalletTransaction.created_at.desc()).limit(20)
    txs = (await db.execute(tx_stmt)).scalars().all()

    return WalletResponse(
        wallet_id=wallet.id,
        user_id=wallet.user_id,
        balance=float(wallet.balance),
        recent_transactions=[
            WalletTransactionResponse(
                id=t.id,
                transaction_type=t.transaction_type,
                amount=float(t.amount),
                balance_before=float(t.balance_before),
                balance_after=float(t.balance_after),
                reference_type=t.reference_type,
                reference_id=t.reference_id,
                description=t.description,
                created_at=t.created_at
            ) for t in txs
        ]
    )

@router.post("/recharge", response_model=WalletResponse)
async def customer_wallet_recharge(
    payload: CustomerTopUpRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await WalletService.credit_wallet_atomic(
        db=db,
        user_id=current_user.id,
        amount=Decimal(str(payload.token_amount)),
        reference_type="ONLINE_TOPUP",
        reference_id=f"TOP-{current_user.id}",
        description=f"Online Top-up via {payload.payment_method or 'UPI'}"
    )

    stmt = select(Wallet).where(Wallet.user_id == current_user.id)
    wallet = (await db.execute(stmt)).scalar_one()

    tx_stmt = select(WalletTransaction).where(
        WalletTransaction.wallet_id == wallet.id
    ).order_by(WalletTransaction.created_at.desc()).limit(20)
    txs = (await db.execute(tx_stmt)).scalars().all()

    return WalletResponse(
        wallet_id=wallet.id,
        user_id=wallet.user_id,
        balance=float(wallet.balance),
        recent_transactions=[
            WalletTransactionResponse(
                id=t.id,
                transaction_type=t.transaction_type,
                amount=float(t.amount),
                balance_before=float(t.balance_before),
                balance_after=float(t.balance_after),
                reference_type=t.reference_type,
                reference_id=t.reference_id,
                description=t.description,
                created_at=t.created_at
            ) for t in txs
        ]
    )

@router.post("/top-up", response_model=WalletResponse)
async def admin_counter_deposit(
    payload: AdminCreditRequest,
    admin_user: User = Depends(require_role([UserRole.ADMIN])),
    db: AsyncSession = Depends(get_db)
):
    await WalletService.credit_wallet_atomic(
        db=db,
        user_id=payload.target_user_id,
        amount=Decimal(str(payload.token_amount)),
        reference_type="ADMIN_CREDIT",
        reference_id=f"ADM-{admin_user.id}",
        description=payload.notes or f"Manual deposit credited by Admin #{admin_user.name}"
    )

    stmt = select(Wallet).where(Wallet.user_id == payload.target_user_id)
    wallet = (await db.execute(stmt)).scalar_one()

    tx_stmt = select(WalletTransaction).where(
        WalletTransaction.wallet_id == wallet.id
    ).order_by(WalletTransaction.created_at.desc()).limit(1)
    tx = (await db.execute(tx_stmt)).scalar_one()

    return WalletResponse(
        wallet_id=wallet.id,
        user_id=wallet.user_id,
        balance=float(wallet.balance),
        recent_transactions=[
            WalletTransactionResponse(
                id=tx.id,
                transaction_type=tx.transaction_type,
                amount=float(tx.amount),
                balance_before=float(tx.balance_before),
                balance_after=float(tx.balance_after),
                reference_type=tx.reference_type,
                reference_id=tx.reference_id,
                description=tx.description,
                created_at=tx.created_at
            )
        ]
    )

