from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from app.models.user import UserRole

class UserRegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    mobile: str = Field(..., pattern=r"^\+?\d{10,15}$")
    password: str = Field(..., min_length=6)

class UserLoginRequest(BaseModel):
    # Unified Login: supports either Email or 10-digit Mobile
    identifier: str = Field(..., description="Email address or 10-digit mobile number")
    password: str = Field(..., min_length=1)

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    name: str
    email: str
    role: UserRole
    canteen_id: Optional[int] = None
    wallet_balance: float

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    mobile: str
    role: UserRole
    canteen_id: Optional[int] = None
    profile_image_url: Optional[str] = None
    wallet_balance: float

    class Config:
        from_attributes = True

class FcmTokenUpdateRequest(BaseModel):
    fcm_token: str = Field(..., min_length=10)
