import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal
from pydantic import Field, condecimal
from ninja import Schema

CategoryType = Literal["expense", "income"]


class BudgetCategoryIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    limit_amount: condecimal(max_digits=12, decimal_places=2)
    category_type: CategoryType = "expense"
    icon_code: int | None = None
    color_hex: str | None = Field(default=None, max_length=9)


class BudgetCategoryPatch(Schema):
    name: str | None = None
    limit_amount: condecimal(max_digits=12, decimal_places=2) | None = None
    category_type: CategoryType | None = None
    icon_code: int | None = None
    color_hex: str | None = None


class BudgetCategoryOut(Schema):
    id: uuid.UUID
    name: str
    limit_amount: condecimal(max_digits=12, decimal_places=2)
    spent_amount: condecimal(max_digits=12, decimal_places=2)
    category_type: CategoryType
    icon_code: int | None = None
    color_hex: str | None = None
    created_at: datetime
