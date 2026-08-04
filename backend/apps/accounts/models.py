import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class Account:
    id: uuid.UUID
    user_id: str
    name: str
    balance: Decimal
    created_at: datetime
