from pydantic import condecimal
from ninja import Schema


class SuggestIn(Schema):
    excess_funds: condecimal(max_digits=12, decimal_places=2)


class SuggestItemOut(Schema):
    goalName: str
    amount: float
    subgoalName: str | None = None


class SuggestOut(Schema):
    suggestions: list[SuggestItemOut]
    reasoning: str
