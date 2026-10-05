import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from datetime import datetime, timedelta
from app.config import settings
from app.database import AsyncSessionLocal
from app.models.order import Order, OrderStatus, OrderType
from app.soft_computing.executor import cpu_pool
from app.routers import auth, users, canteens, orders, wallet, kitchen, admin, ws_router
from app.websocket_manager import ws_manager

async def advance_order_scheduler_task():
    while True:
        try:
            await asyncio.sleep(30)
            async with AsyncSessionLocal() as session:
                trigger_time = datetime.utcnow() + timedelta(minutes=15)
                stmt = select(Order).where(
                    Order.order_type == OrderType.SCHEDULED,
                    Order.status == OrderStatus.PLACED,
                    Order.scheduled_at <= trigger_time
                )
                scheduled_orders = (await session.execute(stmt)).scalars().all()

                for o in scheduled_orders:
                    o.status = OrderStatus.CONFIRMED
                    await ws_manager.broadcast_to_kitchen(
                        canteen_id=o.canteen_id,
                        event_type="ADVANCE_ORDER_TRIGGERED",
                        payload={"order_number": o.order_number, "token": o.order_number.split("-")[-1]}
                    )
                await session.commit()
        except asyncio.CancelledError:
            break
        except Exception:
            await asyncio.sleep(5)

@asynccontextmanager
async def lifespan(app: FastAPI):
    import os
    is_serverless = bool(os.environ.get("VERCEL"))
    scheduler = None
    if not is_serverless:
        scheduler = asyncio.create_task(advance_order_scheduler_task())
    yield
    if scheduler:
        scheduler.cancel()
    if not is_serverless:
        cpu_pool.shutdown()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_origin_regex=r"https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(users.router, prefix=settings.API_V1_STR)
app.include_router(wallet.router, prefix=settings.API_V1_STR)
app.include_router(orders.router, prefix=settings.API_V1_STR)
app.include_router(canteens.router, prefix=settings.API_V1_STR)
app.include_router(kitchen.router, prefix=settings.API_V1_STR)
app.include_router(admin.router, prefix=settings.API_V1_STR)
app.include_router(ws_router.router, prefix=settings.API_V1_STR)

@app.middleware("http")
async def ensure_api_prefix_middleware(request: Request, call_next):
    path = request.scope.get("path", "")
    if path.startswith("/v1/"):
        path = "/api" + path
    elif path == "/v1":
        path = "/api/v1"
    request.scope["path"] = path if (path and path.startswith("/")) else ("/" + path.lstrip("/"))
    return await call_next(request)

@app.get("/")
@app.get("/api")
async def root_index():
    return {
        "status": "online",
        "service": "Smart Canteen API",
        "version": settings.VERSION,
        "docs": "/docs",
        "health": "/health"
    }

@app.get("/health")
@app.get("/api/health")
@app.get("/api/v1/health")
async def health_check():
    return {"status": "healthy", "version": settings.VERSION}

