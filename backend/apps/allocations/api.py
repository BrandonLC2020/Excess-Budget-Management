from ninja import Router
from config.auth import JWTAuth
from .schemas import AllocationIn, AllocationPatch, AllocationOut
from .services import (
    list_allocations,
    create_allocation,
    get_allocation,
    update_allocation,
    delete_allocation,
)

router = Router(tags=["allocations"], auth=JWTAuth())


@router.get("", response=list[AllocationOut], summary="List allocations")
def list_(request, goal_id: str | None = None):
    return list_allocations(request.auth, goal_id=goal_id)


@router.post("", response={201: AllocationOut}, summary="Create allocation")
def create(request, payload: AllocationIn):
    return 201, create_allocation(request.auth, payload)


@router.get("/{allocation_id}", response=AllocationOut, summary="Get allocation")
def get(request, allocation_id: str):
    return get_allocation(request.auth, allocation_id)


@router.patch("/{allocation_id}", response=AllocationOut, summary="Update allocation")
def patch(request, allocation_id: str, payload: AllocationPatch):
    return update_allocation(request.auth, allocation_id, payload)


@router.delete("/{allocation_id}", response={204: None}, summary="Delete allocation")
def delete(request, allocation_id: str):
    delete_allocation(request.auth, allocation_id)
    return 204, None
