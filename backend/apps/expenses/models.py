import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass
class Expense:
    id: uuid.UUID
    user_id: str
    budget_category_id: uuid.UUID
    account_id: uuid.UUID | None
    amount: Decimal
    description: str
    date: date
    created_at: datetime
