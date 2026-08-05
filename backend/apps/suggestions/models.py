import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class AllocationSuggestion:
    id: uuid.UUID
    user_id: str
    excess_funds: Decimal
    response_json: dict
    created_at: datetime
