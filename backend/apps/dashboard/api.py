from ninja import Router
from config.auth import JWTAuth
from .schemas import DashboardSummaryOut
from .services import dashboard_summary

router = Router(tags=["dashboard"], auth=JWTAuth())


@router.get("/summary", response=DashboardSummaryOut, summary="Aggregate read for home")
def summary(request):
    return dashboard_summary(request.auth)
