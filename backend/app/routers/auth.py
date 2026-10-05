from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User, UserRole
from app.models.wallet import Wallet
from app.schemas.auth import UserRegisterRequest, UserLoginRequest, TokenResponse, UserResponse
from app.core.security import verify_password, get_password_hash, create_access_token
from app.core.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(payload: UserRegisterRequest, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where((User.mobile == payload.mobile) | (User.email == payload.email))
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this mobile number or email already exists."
        )

    new_user = User(
        name=payload.name,
        email=payload.email,
        mobile=payload.mobile,
        password_hash=get_password_hash(payload.password),
        role=UserRole.CUSTOMER,
        is_active=True
    )
    db.add(new_user)
    await db.flush()

    new_wallet = Wallet(user_id=new_user.id, balance=0.00)
    db.add(new_wallet)
    await db.commit()

    return {"status": "success", "message": "User registered successfully", "user_id": new_user.id}

@router.post("/login", response_model=TokenResponse)
async def login(payload: UserLoginRequest, db: AsyncSession = Depends(get_db)):
    """
    Unified Authentication Endpoint:
    Accepts identifier (either 10-digit mobile number OR email) + password.
    Returns TokenResponse containing JWT, user profile, and current wallet balance.
    """
    ident = payload.identifier.strip()
    stmt = select(User).where((User.mobile == ident) | (User.email == ident))
    user = (await db.execute(stmt)).scalar_one_or_none()

    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please check your email/mobile and password."
        )

    w_stmt = select(Wallet).where(Wallet.user_id == user.id)
    wallet = (await db.execute(w_stmt)).scalar_one_or_none()
    bal = float(wallet.balance) if wallet else 0.0

    token = create_access_token(data={
        "sub": str(user.id),
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "canteen_id": user.canteen_id
    })

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        name=user.name,
        email=user.email,
        role=user.role,
        canteen_id=user.canteen_id,
        wallet_balance=bal
    )

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    w_stmt = select(Wallet).where(Wallet.user_id == current_user.id)
    wallet = (await db.execute(w_stmt)).scalar_one_or_none()
    return UserResponse(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        mobile=current_user.mobile,
        role=current_user.role,
        canteen_id=current_user.canteen_id,
        profile_image_url=current_user.profile_image_url,
        wallet_balance=float(wallet.balance) if wallet else 0.0
    )
