from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from app.models.order import OrderType, OrderStatus

class OrderItemRequest(BaseModel):
    menu_item_id: int
    quantity: int = Field(..., gt=0)

class OrderCreateRequest(BaseModel):
    canteen_id: int
    order_type: OrderType = OrderType.IMMEDIATE
    scheduled_at: Optional[datetime] = None
    items: List[OrderItemRequest] = Field(..., min_items=1)

class OrderItemResponse(BaseModel):
    id: int
    menu_item_id: int
    item_name: str
    hsn_sac_code: str = "996331"
    gst_rate_percent: float = 5.0
    taxable_value: float = 0.0
    cgst_amount: float = 0.0
    sgst_amount: float = 0.0
    igst_amount: float = 0.0
    unit_price: float
    quantity: int
    total_price: float

    class Config:
        from_attributes = True

class OrderResponse(BaseModel):
    id: int
    order_number: str
    invoice_number: Optional[str] = None
    canteen_id: int
    user_id: int
    order_type: OrderType
    status: OrderStatus
    scheduled_at: Optional[datetime] = None
    subtotal_taxable_value: float = 0.0
    total_cgst_amount: float = 0.0
    total_sgst_amount: float = 0.0
    total_igst_amount: float = 0.0
    total_tax_amount: float = 0.0
    total_amount: float
    wallet_balance_remaining: Optional[float] = None
    digital_token: str
    items: List[OrderItemResponse] = []
    created_at: datetime

    class Config:
        from_attributes = True

class InvoiceLineItem(BaseModel):
    item_name: str
    hsn_sac_code: str
    quantity: int
    unit_price: float
    taxable_value: float
    gst_rate_percent: float
    cgst_amount: float
    sgst_amount: float
    igst_amount: float
    line_total: float

class InvoiceResponse(BaseModel):
    invoice_number: str
    order_number: str
    invoice_date: datetime
    seller_name: str
    seller_legal_name: Optional[str] = None
    seller_gstin: Optional[str] = None
    seller_address: Optional[str] = None
    buyer_name: str
    buyer_mobile: Optional[str] = None
    is_tax_inclusive: bool = True
    line_items: List[InvoiceLineItem]
    subtotal_taxable_value: float
    total_cgst: float
    total_sgst: float
    total_igst: float
    total_tax: float
    grand_total: float

class OrderStatusUpdateRequest(BaseModel):
    new_status: OrderStatus
    expected_current_status: Optional[OrderStatus] = None
    notes: Optional[str] = None

class OrderCancelRequest(BaseModel):
    reason: Optional[str] = "Customer requested cancellation"
