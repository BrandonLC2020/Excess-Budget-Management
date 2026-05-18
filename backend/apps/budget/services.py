from .models import BudgetCategory
from apps.common.permissions import get_owned_or_404


def list_categories(user):
    return list(BudgetCategory.objects.filter(user=user))


def create_category(user, payload) -> BudgetCategory:
    return BudgetCategory.objects.create(
        user=user,
        name=payload.name,
        limit_amount=payload.limit_amount,
        category_type=payload.category_type,
        icon_code=payload.icon_code,
        color_hex=payload.color_hex,
    )


def get_category(user, category_id) -> BudgetCategory:
    return get_owned_or_404(BudgetCategory, category_id, user)


def update_category(user, category_id, payload) -> BudgetCategory:
    cat = get_owned_or_404(BudgetCategory, category_id, user)
    if payload.name is not None:
        cat.name = payload.name
    if payload.limit_amount is not None:
        cat.limit_amount = payload.limit_amount
    if payload.category_type is not None:
        cat.category_type = payload.category_type
    if payload.icon_code is not None:
        cat.icon_code = payload.icon_code
    if payload.color_hex is not None:
        cat.color_hex = payload.color_hex
    cat.save()
    return cat


def delete_category(user, category_id) -> None:
    cat = get_owned_or_404(BudgetCategory, category_id, user)
    cat.delete()
