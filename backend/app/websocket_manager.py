from fastapi import WebSocket
from typing import Dict, List, Any
import json
import logging

logger = logging.getLogger("smart_canteen.websocket")

class ConnectionManager:
    def __init__(self):
        # Kitchen rooms partitioned by canteen_id: { canteen_id: [WebSocket, ...] }
        self.kitchen_rooms: Dict[int, List[WebSocket]] = {}
        # Customer connections partitioned by user_id: { user_id: [WebSocket, ...] }
        self.customer_rooms: Dict[int, List[WebSocket]] = {}
        # Reverse lookup for fast socket cleanup: { WebSocket: ("kitchen", id) or ("customer", id) }
        self.socket_bindings: Dict[WebSocket, tuple] = {}

    async def register_customer(self, user_id: int, websocket: WebSocket):
        if user_id not in self.customer_rooms:
            self.customer_rooms[user_id] = []
        self.customer_rooms[user_id].append(websocket)
        self.socket_bindings[websocket] = ("customer", user_id)
        logger.info(f"[WS Secure] Customer #{user_id} registered. Active devices: {len(self.customer_rooms[user_id])}")

    async def register_kitchen(self, canteen_id: int, websocket: WebSocket):
        if canteen_id not in self.kitchen_rooms:
            self.kitchen_rooms[canteen_id] = []
        self.kitchen_rooms[canteen_id].append(websocket)
        self.socket_bindings[websocket] = ("kitchen", canteen_id)
        logger.info(f"[WS Secure] Kitchen screen registered for Canteen #{canteen_id}. Active: {len(self.kitchen_rooms[canteen_id])}")

    def unregister(self, websocket: WebSocket):
        binding = self.socket_bindings.pop(websocket, None)
        if not binding:
            return
        b_type, b_id = binding
        if b_type == "customer" and b_id in self.customer_rooms:
            if websocket in self.customer_rooms[b_id]:
                self.customer_rooms[b_id].remove(websocket)
        elif b_type == "kitchen" and b_id in self.kitchen_rooms:
            if websocket in self.kitchen_rooms[b_id]:
                self.kitchen_rooms[b_id].remove(websocket)
        logger.info(f"[WS Secure] Unregistered {b_type} socket for ID #{b_id}")

    async def broadcast_to_kitchen(self, canteen_id: int, event_type: str, payload: Any):
        if canteen_id in self.kitchen_rooms:
            message = json.dumps({"type": event_type, "data": payload})
            dead = []
            for ws in list(self.kitchen_rooms[canteen_id]):
                try:
                    await ws.send_text(message)
                except Exception:
                    dead.append(ws)
            for ws in dead:
                self.unregister(ws)

    async def send_to_user(self, user_id: int, event_type: str, payload: Any):
        if user_id in self.customer_rooms:
            message = json.dumps({"type": event_type, "data": payload})
            dead = []
            for ws in list(self.customer_rooms[user_id]):
                try:
                    await ws.send_text(message)
                except Exception:
                    dead.append(ws)
            for ws in dead:
                self.unregister(ws)

ws_manager = ConnectionManager()
