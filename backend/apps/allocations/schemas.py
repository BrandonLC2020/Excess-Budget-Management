import uuid
import datetime as dt
from decimal import Decimal
from pydantic import condecimal
from ninja import Schema


class AllocationIn(Schema):
    goal_id: uuid.UUID
    amount: condecimal(max_digits=12, decimal_places=2)
    sub_goal_id: uuid.UUID | None = None
    account_id: uuid.UUID | None = None


class AllocationPatch(Schema):
    goal_id: uuid.UUID | None = None
    amount: condecimal(max_digits=12, decimal_places=2) | None = None
    sub_goal_id: uuid.UUID | None = None
    account_id: uuid.UUID | None = None


class AllocationOut(Schema):
    id: uuid.UUID
    goal_id: uuid.UUID
    sub_goal_id: uuid.UUID | None = None
    account_id: uuid.UUID | None = None
    amount: Decimal
    created_at: dt.datetime


class AllocationSummaryOut(Schema):
    totalSavings: float
    totalPurchases: float
