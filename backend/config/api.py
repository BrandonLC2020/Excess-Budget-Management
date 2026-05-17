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


@api.get("/health", tags=["meta"], summary="Health check", auth=None)
def health(request):
    return {"status": "ok"}
