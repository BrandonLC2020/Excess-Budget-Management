from decimal import Decimal
from apps.common.money import to_cents, from_cents


def test_to_cents_converts_whole_dollars():
    assert to_cents(Decimal("45.00")) == 4500


def test_to_cents_converts_fractional_cents_with_rounding():
    assert to_cents(Decimal("10.005")) == 1001  # ROUND_HALF_UP


def test_from_cents_converts_back_to_two_decimal_places():
    assert from_cents(4500) == Decimal("45.00")


def test_from_cents_handles_negative_values():
    assert from_cents(-500) == Decimal("-5.00")


def test_round_trip_is_exact_for_typical_amounts():
    for dollars in ["0.00", "0.01", "12.34", "1000000.99"]:
        assert from_cents(to_cents(Decimal(dollars))) == Decimal(dollars)
