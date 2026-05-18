import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import Field, condecimal
from ninja import Schema


class AccountIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    balance: condecimal(ge=Decimal("0"), max_digits=12, decimal_places=2) = Decimal("0")


class AccountPatch(Schema):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    balance: condecimal(ge=Decimal("0"), max_digits=12, decimal_places=2) | None = None


class AccountOut(Schema):
    id: uuid.UUID
    name: str
    balance: Decimal
    created_at: datetime
