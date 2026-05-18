from ninja import NinjaAPI

api = NinjaAPI(
    title="Excess Budget API",
    version="1.0.0",
    description="Django backend replacing Supabase for Excess Budget Management.",
)

from apps.common.exceptions import AppError  # noqa: E402


@api.exception_handler(AppError)
def handle_app_error(request, exc: AppError):
    return api.create_response(
        request,
        {"error": {"code": exc.code, "message": exc.message, "details": exc.details}},
        status=exc.status_code,
    )


from apps.users.api import router as users_router  # noqa: E402

api.add_router("/auth", users_router)

from apps.accounts.api import router as accounts_router  # noqa: E402

api.add_router("/accounts", accounts_router)

from apps.income.api import router as income_router  # noqa: E402

api.add_router("/income", income_router)

from apps.budget.api import router as budget_router  # noqa: E402

api.add_router("/budget", budget_router)

from apps.goals.api import router as goals_router  # noqa: E402

api.add_router("/goals", goals_router)


@api.get("/health", tags=["meta"], summary="Health check", auth=None)
def health(request):
    return {"status": "ok"}
