from fastapi import APIRouter, Depends, status, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from app.database import get_db
from app.models.user import User, UserRole
from app.models.order import Order, OrderStatus
from app.models.wallet import Wallet
from app.schemas.order import OrderCreateRequest, OrderResponse, OrderItemResponse, OrderCancelRequest, InvoiceResponse, InvoiceLineItem
from app.services.order_service import OrderService
from app.core.deps import get_current_user

router = APIRouter(prefix="/orders", tags=["Orders"])

@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def place_order(
    payload: OrderCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    order = await OrderService.create_order_atomic(db=db, user_id=current_user.id, payload=payload)
    
    stmt = select(Order).where(Order.id == order.id).options(selectinload(Order.items))
    loaded_order = (await db.execute(stmt)).scalar_one()

    w_stmt = select(Wallet).where(Wallet.user_id == current_user.id)
    wallet = (await db.execute(w_stmt)).scalar_one_or_none()

    return OrderResponse(
        id=loaded_order.id,
        order_number=loaded_order.order_number,
        invoice_number=loaded_order.invoice_number,
        canteen_id=loaded_order.canteen_id,
        user_id=loaded_order.user_id,
        order_type=loaded_order.order_type,
        status=loaded_order.status,
        scheduled_at=loaded_order.scheduled_at,
        subtotal_taxable_value=float(loaded_order.subtotal_taxable_value or 0.0),
        total_cgst_amount=float(loaded_order.total_cgst_amount or 0.0),
        total_sgst_amount=float(loaded_order.total_sgst_amount or 0.0),
        total_igst_amount=float(loaded_order.total_igst_amount or 0.0),
        total_tax_amount=float(loaded_order.total_tax_amount or 0.0),
        total_amount=float(loaded_order.total_amount),
        wallet_balance_remaining=float(wallet.balance) if wallet else 0.0,
        digital_token=loaded_order.order_number.split("-")[-1],
        items=[
            OrderItemResponse(
                id=it.id,
                menu_item_id=it.menu_item_id,
                item_name=it.item_name,
                hsn_sac_code=it.hsn_sac_code or "996331",
                gst_rate_percent=float(it.gst_rate_percent or 5.0),
                taxable_value=float(it.taxable_value or 0.0),
                cgst_amount=float(it.cgst_amount or 0.0),
                sgst_amount=float(it.sgst_amount or 0.0),
                igst_amount=float(it.igst_amount or 0.0),
                unit_price=float(it.unit_price),
                quantity=it.quantity,
                total_price=float(it.total_price)
            ) for it in loaded_order.items
        ],
        created_at=loaded_order.created_at
    )

@router.get("", response_model=List[OrderResponse])
async def get_user_orders(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Order).where(
        Order.user_id == current_user.id
    ).options(selectinload(Order.items)).order_by(Order.created_at.desc()).limit(limit).offset(offset)
    
    orders = (await db.execute(stmt)).scalars().all()

    return [
        OrderResponse(
            id=o.id,
            order_number=o.order_number,
            invoice_number=o.invoice_number,
            canteen_id=o.canteen_id,
            user_id=o.user_id,
            order_type=o.order_type,
            status=o.status,
            scheduled_at=o.scheduled_at,
            subtotal_taxable_value=float(o.subtotal_taxable_value or 0.0),
            total_cgst_amount=float(o.total_cgst_amount or 0.0),
            total_sgst_amount=float(o.total_sgst_amount or 0.0),
            total_igst_amount=float(o.total_igst_amount or 0.0),
            total_tax_amount=float(o.total_tax_amount or 0.0),
            total_amount=float(o.total_amount),
            digital_token=o.order_number.split("-")[-1],
            items=[
                OrderItemResponse(
                    id=it.id,
                    menu_item_id=it.menu_item_id,
                    item_name=it.item_name,
                    hsn_sac_code=it.hsn_sac_code or "996331",
                    gst_rate_percent=float(it.gst_rate_percent or 5.0),
                    taxable_value=float(it.taxable_value or 0.0),
                    cgst_amount=float(it.cgst_amount or 0.0),
                    sgst_amount=float(it.sgst_amount or 0.0),
                    igst_amount=float(it.igst_amount or 0.0),
                    unit_price=float(it.unit_price),
                    quantity=it.quantity,
                    total_price=float(it.total_price)
                ) for it in o.items
            ],
            created_at=o.created_at
        ) for o in orders
    ]

@router.get("/{order_id}", response_model=OrderResponse)
async def get_order_by_id(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Order).where(Order.id == order_id).options(selectinload(Order.items))
    order = (await db.execute(stmt)).scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    
    # Permission scoping: Customer can only view own order; Staff/Admin can view any order
    if current_user.role == UserRole.CUSTOMER and order.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access to order denied")

    w_stmt = select(Wallet).where(Wallet.user_id == order.user_id)
    wallet = (await db.execute(w_stmt)).scalar_one_or_none()

    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        invoice_number=order.invoice_number,
        canteen_id=order.canteen_id,
        user_id=order.user_id,
        order_type=order.order_type,
        status=order.status,
        scheduled_at=order.scheduled_at,
        subtotal_taxable_value=float(order.subtotal_taxable_value or 0.0),
        total_cgst_amount=float(order.total_cgst_amount or 0.0),
        total_sgst_amount=float(order.total_sgst_amount or 0.0),
        total_igst_amount=float(order.total_igst_amount or 0.0),
        total_tax_amount=float(order.total_tax_amount or 0.0),
        total_amount=float(order.total_amount),
        wallet_balance_remaining=float(wallet.balance) if wallet else 0.0,
        digital_token=order.order_number.split("-")[-1],
        items=[
            OrderItemResponse(
                id=it.id,
                menu_item_id=it.menu_item_id,
                item_name=it.item_name,
                hsn_sac_code=it.hsn_sac_code or "996331",
                gst_rate_percent=float(it.gst_rate_percent or 5.0),
                taxable_value=float(it.taxable_value or 0.0),
                cgst_amount=float(it.cgst_amount or 0.0),
                sgst_amount=float(it.sgst_amount or 0.0),
                igst_amount=float(it.igst_amount or 0.0),
                unit_price=float(it.unit_price),
                quantity=it.quantity,
                total_price=float(it.total_price)
            ) for it in order.items
        ],
        created_at=order.created_at
    )

@router.get("/{order_id}/invoice", response_model=InvoiceResponse)
async def get_order_invoice(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Statutory Tax Invoice Retrieval Endpoint:
    Returns full GST-compliant invoice breakdown with HSN/SAC codes,
    seller GSTIN, line-item taxable values, CGST/SGST split, and grand totals.
    """
    stmt = select(Order).where(Order.id == order_id).options(
        selectinload(Order.items),
        selectinload(Order.canteen)
    )
    order = (await db.execute(stmt)).scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    if current_user.role == UserRole.CUSTOMER and order.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access to tax invoice denied")

    if order.status == OrderStatus.CANCELLED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No active invoice available for a cancelled order")

    # Fetch buyer details
    buyer_stmt = select(User).where(User.id == order.user_id)
    buyer = (await db.execute(buyer_stmt)).scalar_one()

    return InvoiceResponse(
        invoice_number=order.invoice_number or f"INV-PROVISIONAL-{order.order_number}",
        order_number=order.order_number,
        invoice_date=order.created_at,
        seller_name=order.canteen.name,
        seller_legal_name=order.canteen.legal_name or order.canteen.name,
        seller_gstin=order.canteen.gstin or "27AABCS1429B1Z8",
        seller_address=order.canteen.registered_address or order.canteen.location,
        buyer_name=buyer.name,
        buyer_mobile=buyer.mobile,
        is_tax_inclusive=order.tax_inclusive_pricing,
        line_items=[
            InvoiceLineItem(
                item_name=it.item_name,
                hsn_sac_code=it.hsn_sac_code or "996331",
                quantity=it.quantity,
                unit_price=float(it.unit_price),
                taxable_value=float(it.taxable_value or 0.0),
                gst_rate_percent=float(it.gst_rate_percent or 5.0),
                cgst_amount=float(it.cgst_amount or 0.0),
                sgst_amount=float(it.sgst_amount or 0.0),
                igst_amount=float(it.igst_amount or 0.0),
                line_total=float(it.total_price)
            ) for it in order.items
        ],
        subtotal_taxable_value=float(order.subtotal_taxable_value or 0.0),
        total_cgst=float(order.total_cgst_amount or 0.0),
        total_sgst=float(order.total_sgst_amount or 0.0),
        total_igst=float(order.total_igst_amount or 0.0),
        total_tax=float(order.total_tax_amount or 0.0),
        grand_total=float(order.total_amount)
    )

@router.post("/{order_id}/cancel", response_model=OrderResponse)
async def cancel_order(
    order_id: int,
    payload: OrderCancelRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    cancelled_order = await OrderService.cancel_order_atomic(
        db=db,
        order_id=order_id,
        user_id=current_user.id,
        is_admin_or_kitchen=False,
        reason=payload.reason
    )

    w_stmt = select(Wallet).where(Wallet.user_id == current_user.id)
    wallet = (await db.execute(w_stmt)).scalar_one_or_none()

    stmt = select(Order).where(Order.id == cancelled_order.id).options(selectinload(Order.items))
    loaded = (await db.execute(stmt)).scalar_one()

    return OrderResponse(
        id=loaded.id,
        order_number=loaded.order_number,
        invoice_number=loaded.invoice_number,
        canteen_id=loaded.canteen_id,
        user_id=loaded.user_id,
        order_type=loaded.order_type,
        status=loaded.status,
        scheduled_at=loaded.scheduled_at,
        subtotal_taxable_value=float(loaded.subtotal_taxable_value or 0.0),
        total_cgst_amount=float(loaded.total_cgst_amount or 0.0),
        total_sgst_amount=float(loaded.total_sgst_amount or 0.0),
        total_igst_amount=float(loaded.total_igst_amount or 0.0),
        total_tax_amount=float(loaded.total_tax_amount or 0.0),
        total_amount=float(loaded.total_amount),
        wallet_balance_remaining=float(wallet.balance) if wallet else 0.0,
        digital_token=loaded.order_number.split("-")[-1],
        items=[
            OrderItemResponse(
                id=it.id,
                menu_item_id=it.menu_item_id,
                item_name=it.item_name,
                hsn_sac_code=it.hsn_sac_code or "996331",
                gst_rate_percent=float(it.gst_rate_percent or 5.0),
                taxable_value=float(it.taxable_value or 0.0),
                cgst_amount=float(it.cgst_amount or 0.0),
                sgst_amount=float(it.sgst_amount or 0.0),
                igst_amount=float(it.igst_amount or 0.0),
                unit_price=float(it.unit_price),
                quantity=it.quantity,
                total_price=float(it.total_price)
            ) for it in loaded.items
        ],
        created_at=loaded.created_at
    )

@router.delete("/{order_id}", status_code=status.HTTP_200_OK)
async def delete_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Order).where(Order.id == order_id)
    order = (await db.execute(stmt)).scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if order.user_id != current_user.id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    
    # Cascade delete order items and order
    await db.delete(order)
    await db.commit()
    return {"status": "success", "message": f"Order {order_id} deleted successfully"}
