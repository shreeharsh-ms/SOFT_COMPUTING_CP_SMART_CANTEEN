import asyncio
from datetime import time
from app.database import AsyncSessionLocal, Base, engine
from app.models.user import User, UserRole
from app.models.wallet import Wallet
from app.models.canteen import Canteen
from app.models.catalog import Category, MenuItem
from app.models.inventory import Inventory
from app.core.security import get_password_hash
import app.models
_ = app.models

async def seed_data(target_engine=None, target_session_factory=None):
    use_engine = target_engine or engine
    use_session = target_session_factory or AsyncSessionLocal

    async with use_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with use_session() as session:
        print("Seeding Canteens...")
        c1 = Canteen(
            name="North Campus Food Court",
            legal_name="Campus Food Services LLP",
            gstin="27AABCS1429B1Z8",
            registered_address="Block A, Ground Floor, University Central Campus, Pune, MH - 411007",
            description="Multi-cuisine food plaza serving quick lunch combos, pizzas and beverages.",
            location="Block A, Ground Floor",
            opening_time=time(8, 0),
            closing_time=time(21, 0),
            is_open=True,
            image_url="https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500"
        )
        c2 = Canteen(
            name="South Terrace Cafe",
            legal_name="Campus Beverages & Confectioneries Pvt Ltd",
            gstin="27AACCT9821K1Z2",
            registered_address="Block C, 3rd Floor Rooftop, University Central Campus, Pune, MH - 411007",
            description="Specialty coffee bar, sandwiches, wraps, and freshly baked bakery goods.",
            location="Block C, 3rd Floor Rooftop",
            opening_time=time(9, 0),
            closing_time=time(20, 0),
            is_open=True,
            image_url="https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500"
        )
        session.add_all([c1, c2])
        await session.commit()
        await session.refresh(c1)
        await session.refresh(c2)

        print("Seeding Users & Wallets...")
        admin = User(
            name="Campus Administrator",
            email="admin@campus.edu",
            mobile="9876543210",
            password_hash=get_password_hash("Admin@Pass2026!"),
            role=UserRole.ADMIN,
            is_active=True
        )
        cook1 = User(
            name="Chef Ramesh",
            email="ramesh.c1@campus.edu",
            mobile="9876543211",
            password_hash=get_password_hash("Chef@Ramesh26"),
            role=UserRole.KITCHEN,
            canteen_id=c1.id,
            is_active=True
        )
        student = User(
            name="Aarav Sharma",
            email="aarav.student@campus.edu",
            mobile="9876543213",
            password_hash=get_password_hash("Student@Aarav26"),
            role=UserRole.CUSTOMER,
            is_active=True
        )
        session.add_all([admin, cook1, student])
        await session.commit()
        await session.refresh(student)

        # Seed student wallet with 250 initial tokens
        session.add(Wallet(user_id=student.id, balance=250.00))

        print("Seeding Categories & Menu Items...")
        cat1 = Category(canteen_id=c1.id, name="Quick Snacks", display_order=1)
        cat2 = Category(canteen_id=c1.id, name="Beverages", display_order=2)
        session.add_all([cat1, cat2])
        await session.commit()
        await session.refresh(cat1)
        await session.refresh(cat2)

        session.add_all([
            MenuItem(
                canteen_id=c1.id, category_id=cat1.id,
                name="Grilled Cheese Sandwich",
                description="Double layered cheddar and mozzarella with crisp sourdough.",
                price=50.0, original_price=60.0,
                hsn_sac_code="996331", gst_rate_percent=5.00,
                stock_quantity=25,
                preparation_time_minutes=8, is_available=True, is_recommended=True
            ),
            MenuItem(
                canteen_id=c1.id, category_id=cat2.id,
                name="Thick Cold Coffee",
                description="Chilled whipped Arabica coffee with rich vanilla ice cream.",
                price=40.0, original_price=50.0,
                hsn_sac_code="996331", gst_rate_percent=5.00,
                stock_quantity=40,
                preparation_time_minutes=4, is_available=True, is_recommended=True
            )
        ])

        print("Seeding Inventory...")
        session.add_all([
            Inventory(canteen_id=c1.id, item_name="Sandwich Bread", unit="packets", current_quantity=28.0, reorder_level=10.0),
            Inventory(canteen_id=c1.id, item_name="Amul Cheese Slices", unit="packets", current_quantity=15.0, reorder_level=5.0)
        ])

        await session.commit()
        print("Database successfully seeded!")

if __name__ == "__main__":
    asyncio.run(seed_data())
