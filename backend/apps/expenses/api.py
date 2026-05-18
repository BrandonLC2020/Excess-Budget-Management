from ninja import Router
from config.auth import JWTAuth
from .schemas import ExpenseIn, ExpensePatch, ExpenseOut
from .services import (
    list_expenses, create_expense, get_expense, update_expense, delete_expense,
)

router = Router(tags=["expenses"], auth=JWTAuth())


@router.get("", response=list[ExpenseOut], summary="List expenses")
def list_(request, account_id: str | None = None, budget_category_id: str | None = None):
    return list_expenses(request.auth, account_id=account_id, budget_category_id=budget_category_id)


@router.post("", response={201: ExpenseOut}, summary="Create expense")
def create(request, payload: ExpenseIn):
    return 201, create_expense(request.auth, payload)


@router.get("/{expense_id}", response=ExpenseOut, summary="Get expense")
def get(request, expense_id: str):
    return get_expense(request.auth, expense_id)


@router.patch("/{expense_id}", response=ExpenseOut, summary="Update expense")
def patch(request, expense_id: str, payload: ExpensePatch):
    return update_expense(request.auth, expense_id, payload)


@router.delete("/{expense_id}", response={204: None}, summary="Delete expense")
def delete(request, expense_id: str):
    delete_expense(request.auth, expense_id)
    return 204, None
