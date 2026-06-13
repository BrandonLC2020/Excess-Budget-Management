from .models import IncomeSource, ExtraIncome, OvertimeSettings
from apps.common.permissions import get_owned_or_404
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory
from apps.goals.models import Goal, Subgoal
from decimal import Decimal


# ── IncomeSource ──────────────────────────────────────────────────────────────

def list_sources(user):
    return list(IncomeSource.objects.filter(user=user))


def create_source(user, payload) -> IncomeSource:
    return IncomeSource.objects.create(
        user=user,
        name=payload.name,
        expected_amount=payload.expected_amount,
        frequency=payload.frequency,
    )


def get_source(user, source_id) -> IncomeSource:
    return get_owned_or_404(IncomeSource, source_id, user)


def update_source(user, source_id, payload) -> IncomeSource:
    src = get_owned_or_404(IncomeSource, source_id, user)
    if payload.name is not None:
        src.name = payload.name
    if payload.expected_amount is not None:
        src.expected_amount = payload.expected_amount
    if payload.frequency is not None:
        src.frequency = payload.frequency
    src.save()
    return src


def delete_source(user, source_id) -> None:
    src = get_owned_or_404(IncomeSource, source_id, user)
    src.delete()


# ── ExtraIncome ───────────────────────────────────────────────────────────────

def list_extra(user, account_id=None, budget_category_id=None):
    qs = ExtraIncome.objects.filter(user=user)
    if account_id:
        qs = qs.filter(account_id=account_id)
    if budget_category_id:
        qs = qs.filter(budget_category_id=budget_category_id)
    return list(qs)


def create_extra(user, payload) -> ExtraIncome:
    account = None
    if payload.account_id is not None:
        account = get_owned_or_404(Account, payload.account_id, user)

    budget_category = None
    if payload.budget_category_id is not None:
        budget_category = get_owned_or_404(BudgetCategory, payload.budget_category_id, user)

    return ExtraIncome.objects.create(
        user=user,
        amount=payload.amount,
        description=payload.description,
        date_received=payload.date_received,
        account=account,
        budget_category=budget_category,
    )


def get_extra(user, extra_id) -> ExtraIncome:
    return get_owned_or_404(ExtraIncome, extra_id, user)


def update_extra(user, extra_id, payload) -> ExtraIncome:
    ei = get_owned_or_404(ExtraIncome, extra_id, user)
    if payload.amount is not None:
        ei.amount = payload.amount
    if payload.description is not None:
        ei.description = payload.description
    if payload.date_received is not None:
        ei.date_received = payload.date_received
    if payload.account_id is not None:
        ei.account = get_owned_or_404(Account, payload.account_id, user)
    elif "account_id" in payload.model_fields_set and payload.account_id is None:
        # Explicit null clears the link
        ei.account = None

    if payload.budget_category_id is not None:
        ei.budget_category = get_owned_or_404(BudgetCategory, payload.budget_category_id, user)
    elif "budget_category_id" in payload.model_fields_set and payload.budget_category_id is None:
        # Explicit null clears the link
        ei.budget_category = None

    ei.save()
    return ei


def delete_extra(user, extra_id) -> None:
    ei = get_owned_or_404(ExtraIncome, extra_id, user)
    ei.delete()


# ── Overtime Settings & Calculations ──────────────────────────────────────────

def get_overtime_settings(user) -> OvertimeSettings:
    settings_obj, _ = OvertimeSettings.objects.get_or_create(user=user)
    return settings_obj


def update_overtime_settings(user, payload) -> OvertimeSettings:
    settings_obj = get_overtime_settings(user)
    if payload.hourly_base_rate is not None:
        settings_obj.hourly_base_rate = payload.hourly_base_rate
    if payload.overtime_multiplier is not None:
        settings_obj.overtime_multiplier = payload.overtime_multiplier
    if payload.estimated_tax_rate is not None:
        settings_obj.estimated_tax_rate = payload.estimated_tax_rate
    settings_obj.save()
    return settings_obj


def calculate_overtime_projections(user, payload) -> dict:
    settings_obj = get_overtime_settings(user)
    
    base = Decimal(settings_obj.hourly_base_rate)
    mult = Decimal(settings_obj.overtime_multiplier)
    tax = Decimal(settings_obj.estimated_tax_rate)
    
    net_hourly_rate = base * mult * (Decimal("1.00") - tax)
    weekly_overtime_net_income = net_hourly_rate * payload.overtime_hours_per_week
    
    # 52 weeks / 12 months = 4.3333333333 weeks per month
    monthly_overtime_net_income = weekly_overtime_net_income * Decimal("52") / Decimal("12")
    
    # Rounded values for standard fields
    result = {
        "net_hourly_rate": round(net_hourly_rate, 2),
        "weekly_overtime_net_income": round(weekly_overtime_net_income, 2),
        "monthly_overtime_net_income": round(monthly_overtime_net_income, 2),
        "total_hours_needed": None,
        "months_to_complete_standard": None,
        "months_to_complete_with_overtime": None,
        "months_saved": None,
    }
    
    remaining_amount = Decimal("0.00")
    has_target = False
    
    if payload.subgoal_id:
        subgoal = get_owned_or_404(Subgoal, payload.subgoal_id, user)
        remaining_amount = subgoal.target_amount - subgoal.current_amount
        has_target = True
    elif payload.goal_id:
        goal = get_owned_or_404(Goal, payload.goal_id, user)
        remaining_amount = goal.target_amount - goal.current_amount
        has_target = True
        
    if has_target:
        remaining_amount = max(Decimal("0.00"), remaining_amount)
        
        if net_hourly_rate > 0:
            result["total_hours_needed"] = round(remaining_amount / net_hourly_rate, 2)
            
        std_contrib = payload.standard_contribution
        
        if std_contrib > 0:
            result["months_to_complete_standard"] = round(remaining_amount / std_contrib, 2)
            total_monthly = std_contrib + monthly_overtime_net_income
            result["months_to_complete_with_overtime"] = round(remaining_amount / total_monthly, 2)
            result["months_saved"] = round(result["months_to_complete_standard"] - result["months_to_complete_with_overtime"], 2)
        elif monthly_overtime_net_income > 0:
            result["months_to_complete_with_overtime"] = round(remaining_amount / monthly_overtime_net_income, 2)
            
    return result
