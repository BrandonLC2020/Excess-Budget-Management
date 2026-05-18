import uuid
import datetime as dt
from decimal import Decimal
from pydantic import condecimal
from ninja import Schema


class ExpenseIn(Schema):
    budget_category_id: uuid.UUID
    account_id: uuid.UUID | None = None
    amount: condecimal(max_digits=12, decimal_places=2)
    description: str = ""
    date: dt.date


class ExpensePatch(Schema):
    budget_category_id: uuid.UUID | None = None
    account_id: uuid.UUID | None = None
    amount: condecimal(max_digits=12, decimal_places=2) | None = None
    description: str | None = None
    date: dt.date | None = None


class ExpenseOut(Schema):
    id: uuid.UUID
    budget_category_id: uuid.UUID
    account_id: uuid.UUID | None = None
    amount: Decimal
    description: str
    date: dt.date
    created_at: dt.datetime
