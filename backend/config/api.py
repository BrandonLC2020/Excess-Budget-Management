from ninja import NinjaAPI

api = NinjaAPI(
    title="Excess Budget API",
    version="1.0.0",
    description="Django backend replacing Supabase for Excess Budget Management.",
)

@api.get("/health", tags=["meta"], summary="Health check", auth=None)
def health(request):
    return {"status": "ok"}
