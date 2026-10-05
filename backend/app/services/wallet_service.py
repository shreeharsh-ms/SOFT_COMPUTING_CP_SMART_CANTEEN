from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status
from app.models.wallet import Wallet, WalletTransaction, TransactionType

class WalletService:
    @staticmethod
    async def credit_wallet_in_tx(
        db: AsyncSession,
        user_id: int,
        amount: Decimal,
        reference_type: str,
        reference_id: str,
        description: str
    ) -> WalletTransaction:
        # Audit Point #1 & Issue A Hardening:
        # Executes wallet refund/credit INSIDE existing outer ACID transaction block.
        stmt = select(Wallet).where(Wallet.user_id == user_id).with_for_update()
        result = await db.execute(stmt)
        wallet = result.scalar_one_or_none()

        if not wallet:
            wallet = Wallet(user_id=user_id, balance=Decimal("0.00"))
            db.add(wallet)
            await db.flush()

        bal_before = wallet.balance
        wallet.balance += amount
        bal_after = wallet.balance

        tx_type = TransactionType.REFUND if reference_type == "ORDER_REFUND" else TransactionType.CREDIT

        tx = WalletTransaction(
            wallet_id=wallet.id,
            transaction_type=tx_type,
            amount=amount,
            balance_before=bal_before,
            balance_after=bal_after,
            reference_type=reference_type,
            reference_id=reference_id,
            description=description
        )
        db.add(tx)
        await db.flush()
        return tx

    @staticmethod
    async def debit_wallet_in_tx(
        db: AsyncSession,
        user_id: int,
        amount: Decimal,
        reference_type: str,
        reference_id: str,
        description: str
    ) -> WalletTransaction:
        stmt = select(Wallet).where(Wallet.user_id == user_id).with_for_update()
        result = await db.execute(stmt)
        wallet = result.scalar_one_or_none()
        if not wallet:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wallet not found")

        if wallet.balance < amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient wallet tokens. Required: {amount}, Available: {wallet.balance}"
            )

        bal_before = wallet.balance
        wallet.balance -= amount
        bal_after = wallet.balance

        tx = WalletTransaction(
            wallet_id=wallet.id,
            transaction_type=TransactionType.DEBIT,
            amount=amount,
            balance_before=bal_before,
            balance_after=bal_after,
            reference_type=reference_type,
            reference_id=reference_id,
            description=description
        )
        db.add(tx)
        await db.flush()
        return tx

    @staticmethod
    async def credit_wallet_atomic(
        db: AsyncSession,
        user_id: int,
        amount: Decimal,
        reference_type: str,
        reference_id: str,
        description: str
    ) -> WalletTransaction:
        async with (db.begin_nested() if db.in_transaction() else db.begin()):
            return await WalletService.credit_wallet_in_tx(
                db=db,
                user_id=user_id,
                amount=amount,
                reference_type=reference_type,
                reference_id=reference_id,
                description=description
            )
