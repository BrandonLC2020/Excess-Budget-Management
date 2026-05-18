from ninja import Router
from config.auth import JWTAuth
from .schemas import BudgetCategoryIn, BudgetCategoryPatch, BudgetCategoryOut
from .services import (
    list_categories, create_category, get_category, update_category, delete_category,
)

categories_router = Router(tags=["budget"], auth=JWTAuth())


@categories_router.get("", response=list[BudgetCategoryOut], summary="List budget categories")
def list_(request):
    return list_categories(request.auth)


@categories_router.post("", response={201: BudgetCategoryOut}, summary="Create budget category")
def create(request, payload: BudgetCategoryIn):
    return 201, create_category(request.auth, payload)


@categories_router.get("/{category_id}", response=BudgetCategoryOut, summary="Get budget category")
def get(request, category_id: str):
    return get_category(request.auth, category_id)


@categories_router.patch("/{category_id}", response=BudgetCategoryOut, summary="Update budget category")
def patch(request, category_id: str, payload: BudgetCategoryPatch):
    return update_category(request.auth, category_id, payload)


@categories_router.delete("/{category_id}", response={204: None}, summary="Delete budget category")
def delete(request, category_id: str):
    delete_category(request.auth, category_id)
    return 204, None


router = Router(auth=JWTAuth())
router.add_router("/categories", categories_router)
