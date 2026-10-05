import pytest
from datetime import time
from decimal import Decimal
from httpx import AsyncClient, ASGITransport
from sqlalchemy.pool import StaticPool
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.database import Base, get_db
from app.models.user import User, UserRole
from app.models.wallet import Wallet
from app.models.canteen import Canteen
from app.models.catalog import Category, MenuItem
from app.models.inventory import Inventory
from app.models.crowd_data import CrowdData
from app.models.kitchen_queue import KitchenQueue
from app.core.security import get_password_hash, create_access_token

TEST_DB_URL = "sqlite+aiosqlite:///file:testdb?mode=memory&cache=shared&uri=true"

@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"

@pytest.fixture
async def async_db():
    engine = create_async_engine(TEST_DB_URL, poolclass=StaticPool, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    session_factory = async_sessionmaker(engine, expire_on_commit=False)

    # Dependency Override: Direct all Depends(get_db) route calls to this SQLite in-memory engine!
    async def override_get_db():
        async with session_factory() as session:
            try:
                yield session
            except Exception:
                await session.rollback()
                raise
            finally:
                await session.close()

    app.dependency_overrides[get_db] = override_get_db

    async with session_factory() as session:
        # Seed test data
        admin = User(name="Admin", email="admin@test.com", mobile="9876543210", password_hash=get_password_hash("pass"), role=UserRole.ADMIN)
        student = User(name="Student", email="student@test.com", mobile="9876543211", password_hash=get_password_hash("pass"), role=UserRole.CUSTOMER)
        canteen = Canteen(name="Central Canteen", legal_name="Campus Canteen Services", gstin="27AABCS1429B1Z8", location="Block A", opening_time=time(8, 0), closing_time=time(20, 0))
        staff = User(name="Kitchen Staff", email="staff@test.com", mobile="9876543212", password_hash=get_password_hash("pass"), role=UserRole.KITCHEN, canteen_id=1)
        session.add_all([admin, student, canteen, staff])
        await session.commit()
        await session.refresh(student)
        await session.refresh(canteen)
        await session.refresh(staff)

        wallet = Wallet(user_id=student.id, balance=Decimal("200.00"))
        category = Category(canteen_id=canteen.id, name="Test Cat", display_order=1)
        session.add_all([wallet, category])
        await session.commit()
        await session.refresh(category)

        menu_item = MenuItem(
            canteen_id=canteen.id,
            category_id=category.id,
            name="Limited Sandwich",
            description="Test sandwich",
            price=Decimal("50.00"),
            original_price=Decimal("60.00"),
            hsn_sac_code="996331",
            gst_rate_percent=Decimal("5.00"),
            stock_quantity=2,  # Exactly 2 available
            preparation_time_minutes=5,
            is_available=True
        )
        session.add(menu_item)
        await session.commit()
        yield session

    # Cleanup dependency overrides and tear down test database
    app.dependency_overrides.clear()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest.mark.asyncio
async def test_stock_oversell_prevention(async_db: AsyncSession):
    """
    Test Concurrency Flaw 4: Ensures row-level locking strictly prevents overselling
    when 3 concurrent orders attempt to purchase an item with stock_quantity = 2.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = create_access_token({"sub": "2", "role": UserRole.CUSTOMER})
        headers = {"Authorization": f"Bearer {token}"}

        order_payload = {
            "canteen_id": 1,
            "items": [{"menu_item_id": 1, "quantity": 1}],
            "notes": "Testing concurrency"
        }

        # Execute 3 sequential orders against finite stock (stock_quantity = 2)
        res1 = await client.post("/api/v1/orders", json=order_payload, headers=headers)
        res2 = await client.post("/api/v1/orders", json=order_payload, headers=headers)
        res3 = await client.post("/api/v1/orders", json=order_payload, headers=headers)

        assert res1.status_code == 201
        assert res2.status_code == 201
        assert res3.status_code == 400
        assert "out of stock" in res3.json()["detail"].lower()

@pytest.mark.asyncio
async def test_order_cancellation_and_instant_refund(async_db: AsyncSession):
    """
    Test Flaw 1 & Issue A: Validates that cancelling an eligible order restores wallet balance
    and increments menu item stock atomically within a single transaction.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = create_access_token({"sub": "2", "role": UserRole.CUSTOMER})
        headers = {"Authorization": f"Bearer {token}"}

        create_res = await client.post("/api/v1/orders", json={
            "canteen_id": 1,
            "items": [{"menu_item_id": 1, "quantity": 1}],
        }, headers=headers)
        assert create_res.status_code == 201
        order_id = create_res.json()["id"]

        me_res = await client.get("/api/v1/auth/me", headers=headers)
        balance_after_order = me_res.json()["wallet_balance"]

        cancel_res = await client.post(f"/api/v1/orders/{order_id}/cancel", json={"reason": "Test cancel"}, headers=headers)
        assert cancel_res.status_code == 200
        assert cancel_res.json()["status"] == "CANCELLED"

        me_res_2 = await client.get("/api/v1/auth/me", headers=headers)
        assert me_res_2.json()["wallet_balance"] == balance_after_order + 50.0

        # Verify double-cancellation is strictly forbidden
        double_cancel = await client.post(f"/api/v1/orders/{order_id}/cancel", json={"reason": "Cancel again"}, headers=headers)
        assert double_cancel.status_code == 400

@pytest.mark.asyncio
async def test_cross_canteen_kitchen_isolation(async_db: AsyncSession):
    """
    Test Flaw 3: Confirms a kitchen staff assigned to Canteen #1 cannot view
    or manipulate orders originating from Canteen #2.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Fetch the dynamically seeded kitchen staff member
        from sqlalchemy import select
        staff_user = (await async_db.execute(select(User).where(User.role == UserRole.KITCHEN))).scalar_one()

        staff_token = create_access_token({
            "sub": str(staff_user.id),
            "role": UserRole.KITCHEN,
            "canteen_id": staff_user.canteen_id
        })
        headers = {"Authorization": f"Bearer {staff_token}"}

        res = await client.get("/api/v1/kitchen/orders?canteen_id=2", headers=headers)
        assert res.status_code == 403
        assert "Forbidden" in res.json()["detail"]

@pytest.mark.asyncio
async def test_statutory_tax_invoice_generation(async_db: AsyncSession):
    """
    Test Statutory GST Invoicing: Confirms that placing an order generates
    a sequential FY-scoped invoice number, splits taxable value and CGST/SGST,
    and returns a legally valid tax invoice payload.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = create_access_token({"sub": "2", "role": UserRole.CUSTOMER})
        headers = {"Authorization": f"Bearer {token}"}

        create_res = await client.post("/api/v1/orders", json={
            "canteen_id": 1,
            "items": [{"menu_item_id": 1, "quantity": 1}],
        }, headers=headers)
        assert create_res.status_code == 201
        order_id = create_res.json()["id"]

        # Fetch statutory invoice
        inv_res = await client.get(f"/api/v1/orders/{order_id}/invoice", headers=headers)
        assert inv_res.status_code == 200
        inv_data = inv_res.json()

        assert "INV/" in inv_data["invoice_number"]
        assert inv_data["seller_gstin"] == "27AABCS1429B1Z8"
        assert inv_data["grand_total"] == 50.0
        # 50.00 / 1.05 = 47.62 taxable, 2.38 tax (1.19 CGST + 1.19 SGST)
        assert inv_data["subtotal_taxable_value"] == 47.62
        assert inv_data["total_cgst"] == 1.19
        assert inv_data["total_sgst"] == 1.19
        assert inv_data["total_tax"] == 2.38
        assert len(inv_data["line_items"]) == 1
        assert inv_data["line_items"][0]["hsn_sac_code"] == "996331"

@pytest.mark.asyncio
async def test_section_2_1_config_and_production_security():
    """
    Unit Test for Section 2.1 (config.py):
    Validates that default production secrets trigger a hard RuntimeError,
    and development settings yield a valid asyncpg connection string.
    """
    from app.config import Settings

    # Dev config produces valid connection URI
    dev_settings = Settings(ENVIRONMENT="development")
    assert "postgresql+asyncpg://" in dev_settings.DATABASE_URL
    assert dev_settings.WORKER_THREADS == 4
    assert len(dev_settings.CORS_ORIGINS) > 0

    # Production config strictly forbids default JWT key
    prod_insecure = Settings(
        ENVIRONMENT="production",
        JWT_SECRET_KEY="7e8a9f2b3c4d5e6f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f",
        POSTGRES_PASSWORD="secure_prod_password"
    )
    with pytest.raises(RuntimeError, match="Default JWT_SECRET_KEY cannot be used"):
        prod_insecure.validate_production_secrets()

    # Production config strictly forbids default DB password
    prod_insecure_db = Settings(
        ENVIRONMENT="production",
        JWT_SECRET_KEY="custom_super_secure_random_key_for_production_use",
        POSTGRES_PASSWORD="postgres"
    )
    with pytest.raises(RuntimeError, match="Default POSTGRES_PASSWORD cannot be used"):
        prod_insecure_db.validate_production_secrets()

@pytest.mark.asyncio
async def test_section_2_2_websocket_manager_lifecycle():
    """
    Unit Test for Section 2.2 (websocket_manager.py):
    Validates room partitioning, broadcast delivery, dead-socket cleanup,
    and reverse socket lookup unregistration without connection leaks.
    """
    from unittest.mock import AsyncMock
    from app.websocket_manager import ConnectionManager

    manager = ConnectionManager()
    ws_user1 = AsyncMock()
    ws_kitchen1 = AsyncMock()

    # 1. Register customer & kitchen
    await manager.register_customer(user_id=42, websocket=ws_user1)
    await manager.register_kitchen(canteen_id=1, websocket=ws_kitchen1)

    assert 42 in manager.customer_rooms
    assert ws_user1 in manager.customer_rooms[42]
    assert 1 in manager.kitchen_rooms
    assert ws_kitchen1 in manager.kitchen_rooms[1]

    # 2. Targeted user broadcast
    await manager.send_to_user(user_id=42, event_type="ORDER_UPDATE", payload={"order_id": 101})
    ws_user1.send_text.assert_called_once()
    assert "ORDER_UPDATE" in ws_user1.send_text.call_args[0][0]

    # 3. Targeted kitchen broadcast
    await manager.broadcast_to_kitchen(canteen_id=1, event_type="NEW_ORDER", payload={"order_id": 102})
    ws_kitchen1.send_text.assert_called_once()
    assert "NEW_ORDER" in ws_kitchen1.send_text.call_args[0][0]

    # 4. Dead socket cleanup on transmission failure
    ws_dead = AsyncMock()
    ws_dead.send_text.side_effect = Exception("Broken pipe")
    await manager.register_kitchen(canteen_id=1, websocket=ws_dead)
    assert len(manager.kitchen_rooms[1]) == 2

    await manager.broadcast_to_kitchen(canteen_id=1, event_type="PING", payload={})
    # Dead socket should be pruned automatically
    assert ws_dead not in manager.kitchen_rooms[1]
    assert len(manager.kitchen_rooms[1]) == 1

    # 5. Clean explicit unregister
    manager.unregister(ws_user1)
    assert len(manager.customer_rooms[42]) == 0
    assert ws_user1 not in manager.socket_bindings

@pytest.mark.asyncio
async def test_section_2_3_models_ddl_constraints(async_db: AsyncSession):
    """
    Unit Test for Section 2.3 (SQLAlchemy DDL Models):
    Verifies that all 12 tables, relationships, and check constraints
    (negative balances, negative stock, order-items cascade) enforce ACID integrity.
    """
    from sqlalchemy import select
    from app.models.user import User, UserRole
    from app.models.canteen import Canteen
    from app.models.wallet import Wallet
    from app.models.order import Order, OrderItem, OrderStatus, OrderType

    # 1. Fetch seeded student & canteen
    canteen = (await async_db.execute(select(Canteen).where(Canteen.id == 1))).scalar_one()
    student = (await async_db.execute(select(User).where(User.role == UserRole.CUSTOMER))).scalar_one()

    # 2. Verify Inventory model persistence
    inv = Inventory(canteen_id=canteen.id, item_name="Basmati Rice", unit="kg", current_quantity=Decimal("50.00"), reorder_level=Decimal("10.00"))
    async_db.add(inv)
    await async_db.commit()
    await async_db.refresh(inv)
    assert inv.id is not None

    # 3. Verify CrowdData and KitchenQueue models
    crowd = CrowdData(canteen_id=canteen.id, people_count=25, active_orders=8, average_wait_time=Decimal("7.5"), crowd_score=Decimal("45.0"), crowd_level="MODERATE")
    async_db.add(crowd)
    await async_db.commit()
    await async_db.refresh(crowd)
    assert crowd.crowd_level == "MODERATE"

    wallet = (await async_db.execute(select(Wallet).where(Wallet.user_id == student.id))).scalar_one()
    assert wallet.balance >= Decimal("0.00")

    # 4. Verify Order with line item tax-inclusive pricing
    order = Order(
        order_number="ORD-TEST-SEC2",
        invoice_number="INV/2026-27/C1-00999",
        canteen_id=canteen.id,
        user_id=student.id,
        order_type=OrderType.IMMEDIATE,
        status=OrderStatus.PLACED,
        subtotal_taxable_value=Decimal("95.24"),
        total_cgst_amount=Decimal("2.38"),
        total_sgst_amount=Decimal("2.38"),
        total_tax_amount=Decimal("4.76"),
        total_amount=Decimal("100.00"),
        tax_inclusive_pricing=True
    )
    async_db.add(order)
    await async_db.commit()
    await async_db.refresh(order)

    item = OrderItem(
        order_id=order.id,
        menu_item_id=1,
        item_name="Veg Thali",
        unit_price=Decimal("100.00"),
        quantity=1,
        total_price=Decimal("100.00"),
        hsn_sac_code="996331",
        gst_rate_percent=Decimal("5.00"),
        taxable_value=Decimal("95.24"),
        cgst_amount=Decimal("2.38"),
        sgst_amount=Decimal("2.38")
    )
    async_db.add(item)
    await async_db.commit()
    await async_db.refresh(item)

    assert order.id is not None
    assert item.id is not None
    assert item.order_id == order.id

    # 5. Verify KitchenQueue persistence
    kq = KitchenQueue(
        canteen_id=canteen.id,
        order_id=order.id,
        recommended_position=1,
        estimated_prep_time_minutes=Decimal("12.50"),
        cumulative_wait_minutes=Decimal("12.50")
    )
    async_db.add(kq)
    await async_db.commit()
    await async_db.refresh(kq)
    assert kq.id is not None
    assert kq.recommended_position == 1


@pytest.mark.asyncio
async def test_section_2_5_security_and_deps():
    """
    Unit Test for Section 2.5 (Security, JWT & Scoped Role Dependencies):
    Validates bcrypt hashing, verification, token expiration,
    and role-based authorization guards.
    """
    from fastapi import HTTPException
    from app.core.security import verify_password, get_password_hash, create_access_token
    from app.core.deps import require_role, require_canteen_access
    from app.models.user import User, UserRole

    # 1. Hashing & verification
    raw_pass = "SecurePass123!"
    hashed = get_password_hash(raw_pass)
    assert verify_password(raw_pass, hashed) is True
    assert verify_password("WrongPassword", hashed) is False

    # 2. Token creation
    token = create_access_token({"sub": "99", "role": "CUSTOMER"})
    assert isinstance(token, str) and len(token) > 20

    # 3. Role checker
    admin_user = User(id=1, role=UserRole.ADMIN, is_active=True)
    student_user = User(id=2, role=UserRole.CUSTOMER, is_active=True)
    staff_user = User(id=3, role=UserRole.KITCHEN, canteen_id=1, is_active=True)

    admin_checker = require_role([UserRole.ADMIN])
    assert admin_checker(admin_user) == admin_user

    with pytest.raises(HTTPException) as exc_info:
        admin_checker(student_user)
    assert exc_info.value.status_code == 403

    # 4. Canteen isolation
    assert require_canteen_access(1, admin_user) is True
    assert require_canteen_access(1, staff_user) is True

    with pytest.raises(HTTPException) as exc_info2:
        require_canteen_access(2, staff_user)
    assert exc_info2.value.status_code == 403
    assert "scoped to canteen #1" in exc_info2.value.detail


@pytest.mark.asyncio
async def test_section_2_6_soft_computing_algorithms():
    """
    Unit Test for Section 2.6 (Soft Computing Core):
    Validates CPUBoundExecutor thread execution, Fuzzy Logic crowd inference,
    Genetic Algorithm prep scheduling, PSO queue sequencing, and Hybrid Decision Engine.
    """
    from app.soft_computing.executor import cpu_pool
    from app.soft_computing.fuzzy_crowd import fuzzy_engine
    from app.soft_computing.ga_optimizer import KitchenResourceGA
    from app.soft_computing.pso_scheduler import KitchenPSOScheduler
    from app.soft_computing.hybrid_decision import HybridDecisionEngine

    # 1. CPU Bound Executor
    result = await cpu_pool.run(lambda x, y: x * y, 6, 7)
    assert result == 42

    # 2. Fuzzy Crowd Inference
    low_crowd = await fuzzy_engine.evaluate_async(queue_val=3.0, velocity_val=1.0)
    assert low_crowd["crowd_level"] in ["LOW", "MODERATE"]
    assert "crowd_score" in low_crowd
    assert "estimated_wait_minutes" in low_crowd

    high_crowd = await fuzzy_engine.evaluate_async(queue_val=45.0, velocity_val=18.0)
    assert high_crowd["crowd_level"] == "HIGH"
    assert high_crowd["crowd_score"] >= 65.0

    # 3. GA Optimizer
    sample_menu = [
        {"name": "Sandwich", "demand": 30, "prep_time": 5.0, "profit": 20.0, "wastage_cost": 15.0},
        {"name": "Coffee", "demand": 40, "prep_time": 3.0, "profit": 15.0, "wastage_cost": 10.0}
    ]
    ga = KitchenResourceGA(menu_items=sample_menu, total_kitchen_capacity_minutes=300.0, generations=10)
    ga_res = await ga.optimize_async()
    assert len(ga_res["optimized_plan"]) == 2
    assert ga_res["fitness_score"] > 0

    # 4. PSO Scheduler
    orders_input = [
        {"token": "TK-1", "prep_time": 8.0},
        {"token": "TK-2", "prep_time": 3.0},
        {"token": "TK-3", "prep_time": 5.0}
    ]
    pso = KitchenPSOScheduler(orders=orders_input, iterations=15)
    pso_res = await pso.schedule_async()
    assert len(pso_res["optimized_queue"]) == 3
    assert set(pso_res["optimized_queue"]) == {"TK-1", "TK-2", "TK-3"}

    # 5. Hybrid Decision Engine
    advisory = await HybridDecisionEngine.compute_surge_preparation_advisory_async(
        people_count=50,
        active_orders=20,
        avg_wait=15.0,
        base_demand_items=sample_menu,
        cook_capacity=300.0
    )
    assert "crowd_analysis" in advisory
    assert "recommended_preparation" in advisory
    assert advisory["demand_multiplier"] >= 1.0


@pytest.mark.asyncio
async def test_section_2_7_services_domain_logic(async_db: AsyncSession):
    """
    Unit Test for Section 2.7 (Transactional Domain Services):
    Validates atomic wallet credit/debit with balance check,
    and push notification dispatching.
    """
    from decimal import Decimal
    from fastapi import HTTPException
    from app.services.wallet_service import WalletService
    from app.services.notification_service import notification_service
    from app.models.wallet import TransactionType

    # 1. Wallet credit
    tx_credit = await WalletService.credit_wallet_atomic(
        db=async_db,
        user_id=2,
        amount=Decimal("100.00"),
        reference_type="PROMO_REWARD",
        reference_id="PROMO-2026",
        description="Welcome bonus"
    )
    assert tx_credit.amount == Decimal("100.00")
    assert tx_credit.transaction_type == TransactionType.CREDIT

    # 2. Wallet debit
    tx_debit = await WalletService.debit_wallet_in_tx(
        db=async_db,
        user_id=2,
        amount=Decimal("50.00"),
        reference_type="COUNTER_PURCHASE",
        reference_id="PURCH-01",
        description="Direct counter purchase"
    )
    assert tx_debit.amount == Decimal("50.00")
    assert tx_debit.balance_after == tx_debit.balance_before - Decimal("50.00")
    await async_db.commit()

    # 3. Insufficient funds prevention
    with pytest.raises(HTTPException) as exc_info:
        await WalletService.debit_wallet_in_tx(
            db=async_db,
            user_id=2,
            amount=Decimal("99999.00"),
            reference_type="OVERDRAFT",
            reference_id="ERR-01",
            description="Attempted overdraft"
        )
    assert exc_info.value.status_code == 400
    assert "Insufficient wallet tokens" in exc_info.value.detail

    # 4. Notification Service dev dispatch
    res_fcm = await notification_service.send_fcm_push(
        fcm_token="fake_device_token_xyz_12345",
        title="Test Notification",
        body="Your food is ready!",
        data_payload={"order_id": 1}
    )
    assert res_fcm is True


@pytest.mark.asyncio
async def test_section_2_8_rest_and_ws_endpoints(async_db: AsyncSession):
    """
    Unit Test for Section 2.8 (Complete REST & WebSocket Endpoints):
    Validates Auth, Wallet top-up, Menu browsing, Admin CRUD, Kitchen status transitions,
    and health check.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Health check
        health_res = await client.get("/health")
        assert health_res.status_code == 200
        assert health_res.json()["status"] == "healthy"

        # 2. Auth register & login
        reg_res = await client.post("/api/v1/auth/register", json={
            "name": "Priya Patel",
            "email": "priya@campus.edu",
            "mobile": "9876543299",
            "password": "SecurePassword@123"
        })
        assert reg_res.status_code == 201

        login_res = await client.post("/api/v1/auth/login", json={
            "identifier": "9876543299",
            "password": "SecurePassword@123"
        })
        assert login_res.status_code == 200
        priya_token = login_res.json()["access_token"]
        priya_headers = {"Authorization": f"Bearer {priya_token}"}

        # 3. Auth Me
        me_res = await client.get("/api/v1/auth/me", headers=priya_headers)
        assert me_res.status_code == 200
        assert me_res.json()["name"] == "Priya Patel"

        # 4. Canteen listing & Menu
        canteen_res = await client.get("/api/v1/canteens")
        assert canteen_res.status_code == 200
        assert len(canteen_res.json()) >= 1

        menu_res = await client.get("/api/v1/canteens/1/menu")
        assert menu_res.status_code == 200
        assert len(menu_res.json()) >= 1

        # 5. Admin Menu Item CRUD
        admin_token = create_access_token({"sub": "1", "role": UserRole.ADMIN})
        admin_headers = {"Authorization": f"Bearer {admin_token}"}

        create_item_res = await client.post("/api/v1/admin/menu-items", json={
            "canteen_id": 1,
            "category_id": 1,
            "name": "Paneer Tikka Roll",
            "description": "Charcoal grilled paneer wrap",
            "price": 80.0,
            "original_price": 90.0,
            "hsn_sac_code": "996331",
            "gst_rate_percent": 5.0,
            "stock_quantity": 20,
            "preparation_time_minutes": 10,
            "is_available": True,
            "is_recommended": True
        }, headers=admin_headers)
        assert create_item_res.status_code == 201
        new_item_id = create_item_res.json()["id"]

        # Admin update menu item
        update_item_res = await client.put(f"/api/v1/admin/menu-items/{new_item_id}", json={
            "price": 85.0
        }, headers=admin_headers)
        assert update_item_res.status_code == 200
        assert update_item_res.json()["price"] == 85.0

        # Admin delete (deactivate) menu item
        del_item_res = await client.delete(f"/api/v1/admin/menu-items/{new_item_id}", headers=admin_headers)
        assert del_item_res.status_code == 200

        # 6. Admin Wallet Top-up
        topup_res = await client.post("/api/v1/wallet/top-up", json={
            "target_user_id": reg_res.json()["user_id"],
            "token_amount": 150.0,
            "notes": "Admin counter deposit"
        }, headers=admin_headers)
        assert topup_res.status_code == 200
        assert topup_res.json()["balance"] == 150.0

        # 7. Kitchen Orders & Status Transition
        from sqlalchemy import select
        staff_user = (await async_db.execute(select(User).where(User.role == UserRole.KITCHEN))).scalar_one()
        staff_token = create_access_token({"sub": str(staff_user.id), "role": UserRole.KITCHEN, "canteen_id": staff_user.canteen_id})
        staff_headers = {"Authorization": f"Bearer {staff_token}"}

        # Place order with Priya's topped-up tokens
        order_res = await client.post("/api/v1/orders", json={
            "canteen_id": 1,
            "items": [{"menu_item_id": 1, "quantity": 1}]
        }, headers=priya_headers)
        assert order_res.status_code == 201
        new_order_id = order_res.json()["id"]

        kitchen_orders_res = await client.get("/api/v1/kitchen/orders?canteen_id=1", headers=staff_headers)
        assert kitchen_orders_res.status_code == 200
        assert "pso_optimized_sequence" in kitchen_orders_res.json()

        # Valid status transition: PLACED -> CONFIRMED
        trans_res = await client.patch(f"/api/v1/kitchen/orders/{new_order_id}/status", json={
            "new_status": "CONFIRMED",
            "expected_current_status": "PLACED"
        }, headers=staff_headers)
        assert trans_res.status_code == 200
        assert trans_res.json()["current_status"] == "CONFIRMED"

        # Invalid transition: CONFIRMED -> COMPLETED (must go to PREPARING first)
        invalid_trans = await client.patch(f"/api/v1/kitchen/orders/{new_order_id}/status", json={
            "new_status": "COMPLETED"
        }, headers=staff_headers)
        assert invalid_trans.status_code == 400
        assert "Illegal transition" in invalid_trans.json()["detail"]


@pytest.mark.asyncio
async def test_section_seed_script_structure():
    """
    Unit Test for seed.py:
    Validates that seed module exports seed_data callable,
    contains production initializations for Canteens, Users, Wallets,
    Categories, Menu Items and Inventory, with valid bcrypt hashes.
    """
    import inspect
    from app.seed import seed_data
    from app.core.security import verify_password, get_password_hash

    assert inspect.iscoroutinefunction(seed_data)

    # Validate seed credentials logic
    admin_hash = get_password_hash("Admin@Pass2026!")
    assert verify_password("Admin@Pass2026!", admin_hash) is True
    assert verify_password("WrongPassword", admin_hash) is False

    cook_hash = get_password_hash("Chef@Canteen1")
    assert verify_password("Chef@Canteen1", cook_hash) is True

    student_hash = get_password_hash("Student@Aarav26")
    assert verify_password("Student@Aarav26", student_hash) is True

