import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from app.models.order import Order, OrderItem, OrderStatus, OrderStatusHistory
from app.models.catalog import MenuItem
from app.models.user import User
from app.schemas.order import OrderCreateRequest
from app.services.wallet_service import WalletService
from app.services.notification_service import notification_service
from app.websocket_manager import ws_manager

class OrderService:
    @staticmethod
    async def create_order_atomic(db: AsyncSession, user_id: int, payload: OrderCreateRequest) -> Order:
        item_ids = [req.menu_item_id for req in payload.items]
        
        async with (db.begin_nested() if db.in_transaction() else db.begin()):
            stmt = select(MenuItem).where(
                MenuItem.id.in_(item_ids),
                MenuItem.canteen_id == payload.canteen_id
            ).with_for_update()
            result = await db.execute(stmt)
            menu_items_map = {item.id: item for item in result.scalars().all()}

            from decimal import ROUND_HALF_UP

            def split_tax_inclusive(gross: Decimal, gst_pct: Decimal) -> dict:
                """
                Back-calculates net taxable value and tax from tax-inclusive gross amount:
                Formula: taxable_value = gross / (1 + gst_rate / 100)
                Tax amount = gross - taxable_value
                """
                rate_frac = gst_pct / Decimal("100")
                taxable = (gross / (Decimal("1") + rate_frac)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                tax_amt = (gross - taxable).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                return {"taxable_value": taxable, "tax_amount": tax_amt}

            total_amount = Decimal("0.00")
            running_taxable_value = Decimal("0.00")
            running_cgst = Decimal("0.00")
            running_sgst = Decimal("0.00")
            running_igst = Decimal("0.00")
            item_snapshots = []

            # Physical on-campus canteen transactions are intra-state supply (CGST + SGST split)
            is_intra_state = True

            for req_item in payload.items:
                menu_item = menu_items_map.get(req_item.menu_item_id)
                if not menu_item:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"Menu item #{req_item.menu_item_id} not available in canteen #{payload.canteen_id}."
                    )
                if not menu_item.is_available:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Menu item '{menu_item.name}' is currently marked out of stock."
                    )

                if menu_item.stock_quantity is not None:
                    if menu_item.stock_quantity < req_item.quantity:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"Only {menu_item.stock_quantity} servings of '{menu_item.name}' remain. Cannot fulfill {req_item.quantity}."
                        )
                    menu_item.stock_quantity -= req_item.quantity
                    if menu_item.stock_quantity == 0:
                        menu_item.is_available = False

                line_gross = (Decimal(str(menu_item.price)) * req_item.quantity).quantize(Decimal("0.01"))
                item_gst_rate = Decimal(str(menu_item.gst_rate_percent or "5.00"))
                split = split_tax_inclusive(line_gross, item_gst_rate)

                if is_intra_state:
                    half_tax = (split["tax_amount"] / Decimal("2")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                    cgst = half_tax
                    sgst = split["tax_amount"] - half_tax
                    igst = Decimal("0.00")
                else:
                    cgst = Decimal("0.00")
                    sgst = Decimal("0.00")
                    igst = split["tax_amount"]

                total_amount += line_gross
                running_taxable_value += split["taxable_value"]
                running_cgst += cgst
                running_sgst += sgst
                running_igst += igst

                item_snapshots.append({
                    "menu_item_id": menu_item.id,
                    "item_name": menu_item.name,
                    "hsn_sac_code": menu_item.hsn_sac_code or "996331",
                    "gst_rate_percent": item_gst_rate,
                    "taxable_value": split["taxable_value"],
                    "cgst_amount": cgst,
                    "sgst_amount": sgst,
                    "igst_amount": igst,
                    "unit_price": Decimal(str(menu_item.price)),
                    "quantity": req_item.quantity,
                    "total_price": line_gross
                })

            now = datetime.utcnow()
            order_number = f"ORD-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:4].upper()}"

            # Sequential Financial Year Tax Invoice Number (e.g., INV/2026-27/000042)
            fy_start = now.year if now.month >= 4 else now.year - 1
            fy_label = f"{fy_start}-{(fy_start + 1) % 100:02d}"
            
            # Atomic sequence fetch for canteen in current FY
            inv_seq_stmt = select(func.count(Order.id)).where(
                Order.canteen_id == payload.canteen_id,
                Order.invoice_number.isnot(None)
            )
            inv_count = (await db.execute(inv_seq_stmt)).scalar() or 0
            invoice_number = f"INV/{fy_label}/C{payload.canteen_id}-{inv_count + 1:05d}-{uuid.uuid4().hex[:4].upper()}"

            await WalletService.debit_wallet_in_tx(
                db=db,
                user_id=user_id,
                amount=total_amount,
                reference_type="ORDER_PAYMENT",
                reference_id=order_number,
                description=f"Payment for Order #{order_number} (Inv: {invoice_number})"
            )

            order = Order(
                order_number=order_number,
                invoice_number=invoice_number,
                canteen_id=payload.canteen_id,
                user_id=user_id,
                order_type=payload.order_type,
                status=OrderStatus.PLACED,
                scheduled_at=payload.scheduled_at,
                tax_inclusive_pricing=True,
                subtotal_taxable_value=running_taxable_value,
                total_cgst_amount=running_cgst,
                total_sgst_amount=running_sgst,
                total_igst_amount=running_igst,
                total_tax_amount=running_cgst + running_sgst + running_igst,
                total_amount=total_amount,
                payment_status="PAID"
            )
            db.add(order)
            await db.flush()

            for snap in item_snapshots:
                db.add(OrderItem(
                    order_id=order.id,
                    menu_item_id=snap["menu_item_id"],
                    item_name=snap["item_name"],
                    hsn_sac_code=snap["hsn_sac_code"],
                    gst_rate_percent=snap["gst_rate_percent"],
                    taxable_value=snap["taxable_value"],
                    cgst_amount=snap["cgst_amount"],
                    sgst_amount=snap["sgst_amount"],
                    igst_amount=snap["igst_amount"],
                    unit_price=snap["unit_price"],
                    quantity=snap["quantity"],
                    total_price=snap["total_price"]
                ))

            db.add(OrderStatusHistory(
                order_id=order.id,
                status=OrderStatus.PLACED,
                changed_by_user_id=user_id,
                notes="Order placed atomically and tokens debited."
            ))

        await db.refresh(order)

        ws_payload = {
            "order_id": order.id,
            "order_number": order.order_number,
            "token": order.order_number.split("-")[-1],
            "order_type": order.order_type,
            "status": order.status,
            "items": [{"name": snap["item_name"], "quantity": snap["quantity"]} for snap in item_snapshots],
            "created_at": order.created_at.isoformat()
        }
        await ws_manager.broadcast_to_kitchen(order.canteen_id, "NEW_ORDER", ws_payload)

        return order

    @staticmethod
    async def cancel_order_atomic(
        db: AsyncSession,
        order_id: int,
        user_id: int,
        is_admin_or_kitchen: bool = False,
        reason: str = None
    ) -> Order:
        # Audit Point #1 & Issue A Hardening:
        # Guaranteed Single Transaction Atomicity:
        # Status change, stock restore, and wallet credit all happen inside ONE begin() block.
        async with (db.begin_nested() if db.in_transaction() else db.begin()):
            stmt = select(Order).where(Order.id == order_id).options(selectinload(Order.items)).with_for_update()
            order = (await db.execute(stmt)).scalar_one_or_none()

            if not order:
                raise HTTPException(status_code=404, detail="Order not found")

            if not is_admin_or_kitchen and order.user_id != user_id:
                raise HTTPException(status_code=403, detail="Unauthorized to cancel this order")

            if order.status not in [OrderStatus.PLACED, OrderStatus.CONFIRMED]:
                raise HTTPException(
                    status_code=400,
                    detail=f"Cannot cancel order in '{order.status}' state. Food is already being prepared."
                )

            if not is_admin_or_kitchen:
                if datetime.utcnow() - order.created_at.replace(tzinfo=None) > timedelta(minutes=3):
                    raise HTTPException(status_code=400, detail="Cancellation window (3 minutes) has expired.")

            for it in order.items:
                m_stmt = select(MenuItem).where(MenuItem.id == it.menu_item_id).with_for_update()
                menu_item = (await db.execute(m_stmt)).scalar_one_or_none()
                if menu_item and menu_item.stock_quantity is not None:
                    menu_item.stock_quantity += it.quantity
                    if menu_item.stock_quantity > 0:
                        menu_item.is_available = True

            order.status = OrderStatus.CANCELLED
            db.add(OrderStatusHistory(
                order_id=order.id,
                status=OrderStatus.CANCELLED,
                changed_by_user_id=user_id,
                notes=reason or "Order cancelled and tokens refunded."
            ))

            tx = await WalletService.credit_wallet_in_tx(
                db=db,
                user_id=order.user_id,
                amount=order.total_amount,
                reference_type="ORDER_REFUND",
                reference_id=order.order_number,
                description=f"Automatic refund for cancelled Order #{order.order_number}"
            )

        await ws_manager.send_to_user(
            user_id=order.user_id,
            event_type="ORDER_REFUNDED",
            payload={
                "order_id": order.id,
                "order_number": order.order_number,
                "refunded_amount": float(order.total_amount),
                "new_wallet_balance": float(tx.balance_after)
            }
        )

        await ws_manager.broadcast_to_kitchen(
            canteen_id=order.canteen_id,
            event_type="ORDER_CANCELLED",
            payload={"order_id": order.id, "order_number": order.order_number}
        )

        u_stmt = select(User).where(User.id == order.user_id)
        user_obj = (await db.execute(u_stmt)).scalar_one_or_none()
        if user_obj and user_obj.fcm_token:
            await notification_service.send_fcm_push(
                fcm_token=user_obj.fcm_token,
                title="Order Cancelled & Refunded",
                body=f"Your order #{order.order_number} has been cancelled. {order.total_amount} tokens were credited back to your wallet."
            )

        return order
