from ninja import Schema
from pydantic import condecimal


class DashboardSummaryOut(Schema):
    total_balance: condecimal(max_digits=12, decimal_places=2)
    goals_total_target: condecimal(max_digits=12, decimal_places=2)
    goals_total_current: condecimal(max_digits=12, decimal_places=2)
    budgets_total_limit: condecimal(max_digits=12, decimal_places=2)
    budgets_total_spent: condecimal(max_digits=12, decimal_places=2)
