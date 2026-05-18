import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal
from pydantic import Field, condecimal
from ninja import Schema

GoalType = Literal["short_term", "long_term"]
GoalCategory = Literal["savings", "purchase"]


class GoalIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    target_amount: condecimal(max_digits=12, decimal_places=2) = Decimal("0.00")
    target_date: date | None = None
    type: GoalType
    category: GoalCategory = "savings"


class GoalPatch(Schema):
    name: str | None = None
    target_amount: condecimal(max_digits=12, decimal_places=2) | None = None
    target_date: date | None = None
    type: GoalType | None = None
    category: GoalCategory | None = None


class GoalOut(Schema):
    id: uuid.UUID
    name: str
    target_amount: condecimal(max_digits=12, decimal_places=2)
    current_amount: condecimal(max_digits=12, decimal_places=2)
    target_date: date | None = None
    type: GoalType
    category: GoalCategory
    created_at: datetime


class SubgoalIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    target_amount: condecimal(max_digits=12, decimal_places=2)
    current_amount: condecimal(max_digits=12, decimal_places=2) = Decimal("0.00")


class SubgoalPatch(Schema):
    name: str | None = None
    target_amount: condecimal(max_digits=12, decimal_places=2) | None = None
    current_amount: condecimal(max_digits=12, decimal_places=2) | None = None


class SubgoalOut(Schema):
    id: uuid.UUID
    goal_id: uuid.UUID
    name: str
    target_amount: condecimal(max_digits=12, decimal_places=2)
    current_amount: condecimal(max_digits=12, decimal_places=2)
    created_at: datetime


class GoalAccountIn(Schema):
    account_id: uuid.UUID


class GoalAccountOut(Schema):
    goal_id: uuid.UUID
    account_id: uuid.UUID
    created_at: datetime
