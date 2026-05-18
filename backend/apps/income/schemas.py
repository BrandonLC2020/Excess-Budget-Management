import uuid
from datetime import date, datetime
from decimal import Decimal
from pydantic import Field, condecimal
from ninja import Schema


class IncomeSourceIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    expected_amount: condecimal(max_digits=12, decimal_places=2)
    frequency: str


class IncomeSourcePatch(Schema):
    name: str | None = None
    expected_amount: condecimal(max_digits=12, decimal_places=2) | None = None
    frequency: str | None = None


class IncomeSourceOut(Schema):
    id: uuid.UUID
    name: str
    expected_amount: Decimal
    frequency: str
    created_at: datetime


class ExtraIncomeIn(Schema):
    amount: condecimal(max_digits=12, decimal_places=2)
    description: str = ""
    date_received: date
    account_id: uuid.UUID | None = None
    budget_category_id: uuid.UUID | None = None  # Task 11 will wire this to budget.BudgetCategory


class ExtraIncomePatch(Schema):
    amount: condecimal(max_digits=12, decimal_places=2) | None = None
    description: str | None = None
    date_received: date | None = None
    account_id: uuid.UUID | None = None
    budget_category_id: uuid.UUID | None = None  # Task 11 will wire this to budget.BudgetCategory


class ExtraIncomeOut(Schema):
    id: uuid.UUID
    amount: Decimal
    description: str
    date_received: date
    account_id: uuid.UUID | None = None
    budget_category_id: uuid.UUID | None = None  # Will be None until Task 11 adds the FK
    created_at: datetime
