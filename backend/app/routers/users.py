from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.user import User
from app.schemas.auth import FcmTokenUpdateRequest
from app.core.deps import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/fcm-token", status_code=status.HTTP_200_OK)
async def register_device_fcm_token(
    payload: FcmTokenUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Audit Point #9 Hardening:
    Registers or updates the mobile device FCM push token on the user account.
    """
    async with (db.begin_nested() if db.in_transaction() else db.begin()):
        current_user.fcm_token = payload.fcm_token
        db.add(current_user)
    return {"status": "success", "message": "FCM device token registered"}
