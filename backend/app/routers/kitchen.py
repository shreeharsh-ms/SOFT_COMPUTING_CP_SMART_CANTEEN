import time
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User, UserRole
from app.models.order import Order, OrderStatus, OrderStatusHistory
from app.schemas.order import OrderStatusUpdateRequest
from app.soft_computing.pso_scheduler import KitchenPSOScheduler
from app.services.order_service import OrderService
from app.services.notification_service import notification_service
from app.websocket_manager import ws_manager
from app.core.deps import require_role, require_canteen_access

router = APIRouter(prefix="/kitchen", tags=["Kitchen Operations"])

VALID_TRANSITIONS = {
    OrderStatus.PLACED: [OrderStatus.CONFIRMED, OrderStatus.PREPARING, OrderStatus.CANCELLED],
    OrderStatus.CONFIRMED: [OrderStatus.PREPARING, OrderStatus.CANCELLED],
    OrderStatus.PREPARING: [OrderStatus.READY, OrderStatus.CANCELLED],
    OrderStatus.READY: [OrderStatus.COMPLETED],
    OrderStatus.COMPLETED: [],
    OrderStatus.CANCELLED: []
}

_pso_cache = {}

@router.get("/orders")
async def get_active_kitchen_orders(
    canteen_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role([UserRole.KITCHEN, UserRole.ADMIN]))
):
    require_canteen_access(canteen_id, current_user)

    active_stmt = select(Order).where(
        Order.canteen_id == canteen_id,
        Order.status.in_([OrderStatus.PLACED, OrderStatus.CONFIRMED, OrderStatus.PREPARING])
    ).options(selectinload(Order.items)).order_by(Order.created_at.asc())
    
    active_orders = (await db.execute(active_stmt)).scalars().all()

    active_list = []
    pso_input = []

    for o in active_orders:
        est_prep = max(4.0, sum(it.quantity * 2.5 for it in o.items))
        pso_input.append({
            "order_id": o.id,
            "token": o.order_number.split("-")[-1],
            "prep_time": est_prep
        })
        active_list.append({
            "id": o.id,
            "order_number": o.order_number,
            "token": o.order_number.split("-")[-1],
            "status": o.status,
            "order_type": o.order_type,
            "scheduled_at": o.scheduled_at,
            "items": [{"name": it.item_name, "quantity": it.quantity} for it in o.items],
            "estimated_prep_minutes": est_prep
        })

    # Enhanced PSO Caching: keyed on both canteen_id AND order IDs tuple hash
    now = time.time()
    order_set_hash = hash(tuple(o["id"] for o in active_list))
    cache_key = (canteen_id, order_set_hash)

    if cache_key in _pso_cache and (now - _pso_cache[cache_key]["time"] < 30.0):
        pso_sequence = _pso_cache[cache_key]["sequence"]
    else:
        pso = KitchenPSOScheduler(orders=pso_input)
        pso_res = await pso.schedule_async()
        pso_sequence = pso_res["optimized_queue"]
        _pso_cache[cache_key] = {"sequence": pso_sequence, "time": now}

    return {
        "canteen_id": canteen_id,
        "active_backlog_count": len(active_list),
        "pso_optimized_sequence": pso_sequence,
        "orders": active_list
    }

@router.patch("/orders/{order_id}/status")
async def update_kitchen_order_status(
    order_id: int,
    payload: OrderStatusUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role([UserRole.KITCHEN, UserRole.ADMIN]))
):
    stmt = select(Order).where(Order.id == order_id).with_for_update()
    order = (await db.execute(stmt)).scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    require_canteen_access(order.canteen_id, current_user)

    if payload.expected_current_status and order.status != payload.expected_current_status:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Stale update: Order is in status '{order.status}', expected '{payload.expected_current_status}'"
        )

    if payload.new_status not in VALID_TRANSITIONS.get(order.status, []):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Illegal transition from '{order.status}' to '{payload.new_status}'"
        )

    if payload.new_status == OrderStatus.CANCELLED:
        cancelled = await OrderService.cancel_order_atomic(
            db=db,
            order_id=order.id,
            user_id=current_user.id,
            is_admin_or_kitchen=True,
            reason=payload.notes or "Kitchen rejected and auto-refunded order"
        )
        return {"status": "success", "message": "Order cancelled & refunded", "order_id": cancelled.id}

    async with (db.begin_nested() if db.in_transaction() else db.begin()):
        order.status = payload.new_status
        db.add(OrderStatusHistory(
            order_id=order.id,
            status=payload.new_status,
            changed_by_user_id=current_user.id,
            notes=payload.notes
        ))

    await ws_manager.send_to_user(
        user_id=order.user_id,
        event_type="ORDER_STATUS_UPDATE",
        payload={"order_id": order.id, "new_status": order.status}
    )

    await ws_manager.broadcast_to_kitchen(
        canteen_id=order.canteen_id,
        event_type="KITCHEN_ORDER_STATUS_CHANGED",
        payload={"order_id": order.id, "new_status": order.status}
    )

    if payload.new_status == OrderStatus.READY:
        u_stmt = select(User).where(User.id == order.user_id)
        user_obj = (await db.execute(u_stmt)).scalar_one_or_none()
        if user_obj and user_obj.fcm_token:
            await notification_service.send_fcm_push(
                fcm_token=user_obj.fcm_token,
                title="Food is Ready for Pickup!",
                body=f"Order #{order.order_number} (Token: {order.order_number.split('-')[-1]}) is ready at the counter."
            )

    return {"status": "success", "order_id": order.id, "current_status": order.status}
