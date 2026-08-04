"""Firestore has no Decimal type. Every persisted 2-decimal-place field in
this schema — money amounts and OvertimeSettings' two rate fields — is
stored as an integer scaled by 100, converted at the service-layer boundary.
"""
from decimal import Decimal, ROUND_HALF_UP

_SCALE = Decimal("100")
_TWO_PLACES = Decimal("0.01")


def to_cents(amount: Decimal) -> int:
    return int((Decimal(amount) * _SCALE).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def from_cents(cents: int) -> Decimal:
    return (Decimal(cents) / _SCALE).quantize(_TWO_PLACES, rounding=ROUND_HALF_UP)
