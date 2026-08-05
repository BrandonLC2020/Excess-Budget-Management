import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass
class IncomeSource:
    id: uuid.UUID
    user_id: str
    name: str
    expected_amount: Decimal
    frequency: str
    created_at: datetime


@dataclass
class ExtraIncome:
    id: uuid.UUID
    user_id: str
    amount: Decimal
    description: str
    date_received: date
    account_id: uuid.UUID | None
    budget_category_id: uuid.UUID | None
    created_at: datetime


@dataclass
class OvertimeSettings:
    user_id: str
    hourly_base_rate: Decimal
    overtime_multiplier: Decimal
    estimated_tax_rate: Decimal
    created_at: datetime
    updated_at: datetime
