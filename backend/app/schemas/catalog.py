from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import time

class MenuItemBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    description: Optional[str] = None
    price: float = Field(..., ge=0.0)
    original_price: float = Field(..., ge=0.0)
    hsn_sac_code: str = Field(default="996331", min_length=4, max_length=10)
    gst_rate_percent: float = Field(default=5.00, ge=0.0, le=28.0)
    stock_quantity: Optional[int] = Field(default=None, ge=0)
    preparation_time_minutes: int = Field(default=10, ge=1)
    is_available: bool = True
    is_recommended: bool = False
    image_url: Optional[str] = None

class MenuItemCreate(MenuItemBase):
    canteen_id: int
    category_id: int

class MenuItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    original_price: Optional[float] = None
    hsn_sac_code: Optional[str] = None
    gst_rate_percent: Optional[float] = None
    stock_quantity: Optional[int] = None
    preparation_time_minutes: Optional[int] = None
    is_available: Optional[bool] = None
    is_recommended: Optional[bool] = None
    image_url: Optional[str] = None

class MenuItemResponse(MenuItemBase):
    id: int
    canteen_id: int
    category_id: int

    class Config:
        from_attributes = True

class CategoryResponse(BaseModel):
    id: int
    canteen_id: int
    name: str
    description: Optional[str] = None
    display_order: int
    items: List[MenuItemResponse] = []

    class Config:
        from_attributes = True

class CrowdStatus(BaseModel):
    canteen_id: int
    people_count: int
    active_orders: int
    order_velocity_per_minute: float
    estimated_wait_minutes: float
    crowd_score: float
    crowd_level: str

class CanteenResponse(BaseModel):
    id: int
    name: str
    legal_name: Optional[str] = None
    gstin: Optional[str] = None
    registered_address: Optional[str] = None
    description: Optional[str] = None
    location: str
    image_url: Optional[str] = None
    opening_time: time
    closing_time: time
    is_open: bool
    crowd_status: CrowdStatus

    class Config:
        from_attributes = True
