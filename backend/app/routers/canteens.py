from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from datetime import datetime, timedelta
from typing import List
from app.database import get_db
from app.models.canteen import Canteen
from app.models.catalog import Category
from app.models.order import Order, OrderStatus
from app.schemas.catalog import CanteenResponse, CategoryResponse, MenuItemResponse, CrowdStatus
from app.soft_computing.fuzzy_crowd import fuzzy_engine

router = APIRouter(prefix="/canteens", tags=["Canteens & Catalog"])

@router.get("", response_model=List[CanteenResponse])
async def list_canteens(db: AsyncSession = Depends(get_db)):
    stmt = select(Canteen).where(Canteen.is_open == True)
    canteens = (await db.execute(stmt)).scalars().all()

    # Dynamic Crowd Metric: Single SQL GROUP BY over rolling 15-minute window
    fifteen_min_ago = datetime.utcnow() - timedelta(minutes=15)
    
    backlog_stmt = select(Order.canteen_id, func.count(Order.id)).where(
        Order.status.in_([OrderStatus.PLACED, OrderStatus.CONFIRMED, OrderStatus.PREPARING])
    ).group_by(Order.canteen_id)
    backlog_map = dict((await db.execute(backlog_stmt)).all())

    recent_stmt = select(Order.canteen_id, func.count(Order.id)).where(
        Order.created_at >= fifteen_min_ago
    ).group_by(Order.canteen_id)
    recent_map = dict((await db.execute(recent_stmt)).all())

    results = []
    for c in canteens:
        active_orders = backlog_map.get(c.id, 0)
        recent_15m = recent_map.get(c.id, 0)
        velocity = round(recent_15m / 15.0, 2)
        people_approx = int(active_orders * 1.8 + recent_15m * 0.5)

        crowd_eval = await fuzzy_engine.evaluate_async(
            queue_val=float(active_orders),
            velocity_val=float(velocity)
        )

        results.append(CanteenResponse(
            id=c.id,
            name=c.name,
            legal_name=c.legal_name,
            gstin=c.gstin,
            registered_address=c.registered_address,
            description=c.description,
            location=c.location,
            image_url=c.image_url,
            opening_time=c.opening_time,
            closing_time=c.closing_time,
            is_open=c.is_open,
            crowd_status=CrowdStatus(
                canteen_id=c.id,
                people_count=people_approx,
                active_orders=active_orders,
                order_velocity_per_minute=velocity,
                estimated_wait_minutes=crowd_eval["estimated_wait_minutes"],
                crowd_score=crowd_eval["crowd_score"],
                crowd_level=crowd_eval["crowd_level"]
            )
        ))

    return results

@router.get("/{canteen_id}/menu", response_model=List[CategoryResponse])
async def get_canteen_menu(
    canteen_id: int,
    include_inactive: bool = Query(False, description="When true (for admin dashboards), includes deactivated items"),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Category).where(
        Category.canteen_id == canteen_id,
        Category.is_active == True
    ).options(selectinload(Category.items)).order_by(Category.display_order.asc())
    categories = (await db.execute(stmt)).scalars().all()

    return [
        CategoryResponse(
            id=cat.id,
            canteen_id=cat.canteen_id,
            name=cat.name,
            description=cat.description,
            display_order=cat.display_order,
            items=[
                MenuItemResponse(
                    id=i.id,
                    canteen_id=i.canteen_id,
                    category_id=i.category_id,
                    name=i.name,
                    description=i.description,
                    price=float(i.price),
                    original_price=float(i.original_price),
                    hsn_sac_code=i.hsn_sac_code or "996331",
                    gst_rate_percent=float(i.gst_rate_percent or 5.0),
                    stock_quantity=i.stock_quantity,
                    preparation_time_minutes=i.preparation_time_minutes,
                    is_available=i.is_available,
                    is_recommended=i.is_recommended,
                    image_url=i.image_url
                ) for i in cat.items if (i.is_available or include_inactive)
            ]
        ) for cat in categories
    ]
