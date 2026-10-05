from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import jwt
from sqlalchemy import select
import asyncio
import json
import logging
from app.config import settings
from app.database import AsyncSessionLocal
from app.models.user import User, UserRole
from app.websocket_manager import ws_manager

logger = logging.getLogger("smart_canteen.ws_router")
router = APIRouter(prefix="/ws", tags=["Secure WebSockets"])

@router.websocket("/connect")
async def secure_websocket_gateway(websocket: WebSocket):
    """
    First-Frame WebSocket Authentication Handshake:
    Audit Point #2, #14 & Issue D Hardening:
    Enforces a strict 5.0-second async timeout for client to transmit AUTH frame.
    Invalid token or handshake expiration immediately terminates connection with code 1008.
    """
    await websocket.accept()
    authenticated_user = None

    try:
        # Strict 5.0s handshake timeout window
        raw_msg = await asyncio.wait_for(websocket.receive_text(), timeout=5.0)
        data = json.loads(raw_msg)

        if data.get("type") != "AUTH" or not data.get("token"):
            await websocket.send_text(json.dumps({"type": "ERROR", "message": "Expected AUTH frame"}))
            await websocket.close(code=1008)
            return

        token = data["token"]
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id = int(payload.get("sub"))

        async with AsyncSessionLocal() as session:
            stmt = select(User).where(User.id == user_id, User.is_active == True)
            authenticated_user = (await session.execute(stmt)).scalar_one_or_none()

        if not authenticated_user:
            await websocket.close(code=1008)
            return

        subscribed_channels = []

        if authenticated_user.role == UserRole.CUSTOMER:
            await ws_manager.register_customer(authenticated_user.id, websocket)
            subscribed_channels.append(f"user_{authenticated_user.id}")
        elif authenticated_user.role == UserRole.KITCHEN:
            if not authenticated_user.canteen_id:
                await websocket.close(code=1008)
                return
            await ws_manager.register_kitchen(authenticated_user.canteen_id, websocket)
            subscribed_channels.append(f"kitchen_{authenticated_user.canteen_id}")
        elif authenticated_user.role == UserRole.ADMIN:
            await ws_manager.register_customer(authenticated_user.id, websocket)
            subscribed_channels.append(f"user_{authenticated_user.id}")

        await websocket.send_text(json.dumps({
            "type": "AUTH_OK",
            "user_id": authenticated_user.id,
            "role": authenticated_user.role,
            "channels": subscribed_channels
        }))

        # Keepalive loop
        while True:
            client_frame = await websocket.receive_text()
            if client_frame == "ping":
                await websocket.send_text("pong")

    except asyncio.TimeoutError:
        logger.warning("[WS Timeout] Client failed to authenticate within 5.0s window.")
        try:
            await websocket.close(code=1008)
        except Exception:
            pass
    except WebSocketDisconnect:
        ws_manager.unregister(websocket)
    except Exception as e:
        logger.warning(f"[WS Exception] {e}")
        ws_manager.unregister(websocket)
        try:
            await websocket.close(code=1008)
        except Exception:
            pass
