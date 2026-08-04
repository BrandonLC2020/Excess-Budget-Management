import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class BudgetCategory:
    id: uuid.UUID
    user_id: str
    name: str
    limit_amount: Decimal
    spent_amount: Decimal
    icon_code: int | None
    color_hex: str | None
    category_type: str
    created_at: datetime
