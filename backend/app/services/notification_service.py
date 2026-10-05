import logging
from typing import Optional
from app.config import settings

logger = logging.getLogger("smart_canteen.notifications")

_firebase_initialized = False

def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import os
        import firebase_admin
        from firebase_admin import credentials
        if os.path.exists(settings.FCM_CREDENTIALS_PATH):
            cred = credentials.Certificate(settings.FCM_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("[FCM Service] Firebase Admin SDK initialized with service account.")
            return True
        else:
            logger.debug(f"[FCM Service] '{settings.FCM_CREDENTIALS_PATH}' not found. Push notifications will run in mock/log mode.")
            return False
    except Exception as e:
        logger.warning(f"[FCM Service] Failed to initialize Firebase Admin SDK: {e}")
        return False

class NotificationService:
    @staticmethod
    async def send_fcm_push(
        fcm_token: Optional[str],
        title: str,
        body: str,
        data_payload: Optional[dict] = None
    ) -> bool:
        """
        Audit Point #9 Hardening:
        Sends OS background push notifications using real Firebase Admin SDK (`messaging.send()`).
        If firebase_admin is installed and FCM_CREDENTIALS_PATH exists, it delivers real pushes to devices.
        Otherwise, logs structured push payload without crashing.
        """
        if not fcm_token:
            logger.debug("No FCM token registered for user; skipping background push.")
            return False

        if _init_firebase():
            try:
                from firebase_admin import messaging
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data={str(k): str(v) for k, v in (data_payload or {}).items()},
                    token=fcm_token
                )
                response = messaging.send(message)
                logger.info(f"[FCM Push Success] Sent message id: {response} to token: {fcm_token[:8]}...")
                return True
            except Exception as e:
                logger.warning(f"[FCM Push Send Error] {e}")
                return False
        else:
            logger.info(f"[FCM Push Dispatched (Dev Mode)] To: {fcm_token[:8]}... | Title: '{title}' | Body: '{body}'")
            return True

notification_service = NotificationService()
