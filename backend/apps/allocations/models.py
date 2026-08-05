import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class GoalAllocation:
    id: uuid.UUID
    user_id: str
    goal_id: uuid.UUID
    sub_goal_id: uuid.UUID | None
    account_id: uuid.UUID | None
    amount: Decimal
    created_at: datetime
