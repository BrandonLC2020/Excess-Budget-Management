from ninja import Router
from config.auth import JWTAuth
from .schemas import (
    GoalIn, GoalPatch, GoalOut,
    SubgoalIn, SubgoalPatch, SubgoalOut,
    GoalAccountIn, GoalAccountOut,
)
from .services import (
    list_goals, create_goal, get_goal, update_goal, delete_goal,
    list_subgoals, create_subgoal, get_subgoal, update_subgoal, delete_subgoal,
    link_account, unlink_account,
)

router = Router(tags=["goals"], auth=JWTAuth())


# --- Goals ---

@router.get("", response=list[GoalOut], summary="List goals")
def list_(request):
    return list_goals(request.auth)


@router.post("", response={201: GoalOut}, summary="Create goal")
def create(request, payload: GoalIn):
    return 201, create_goal(request.auth, payload)


@router.get("/{goal_id}", response=GoalOut, summary="Get goal")
def get(request, goal_id: str):
    return get_goal(request.auth, goal_id)


@router.patch("/{goal_id}", response=GoalOut, summary="Update goal")
def patch(request, goal_id: str, payload: GoalPatch):
    return update_goal(request.auth, goal_id, payload)


@router.delete("/{goal_id}", response={204: None}, summary="Delete goal")
def delete(request, goal_id: str):
    delete_goal(request.auth, goal_id)
    return 204, None


# --- Subgoals ---

@router.get("/{goal_id}/subgoals", response=list[SubgoalOut], summary="List subgoals")
def list_subs(request, goal_id: str):
    return list_subgoals(request.auth, goal_id)


@router.post("/{goal_id}/subgoals", response={201: SubgoalOut}, summary="Create subgoal")
def create_sub(request, goal_id: str, payload: SubgoalIn):
    return 201, create_subgoal(request.auth, goal_id, payload)


@router.patch("/{goal_id}/subgoals/{sid}", response=SubgoalOut, summary="Update subgoal")
def patch_sub(request, goal_id: str, sid: str, payload: SubgoalPatch):
    return update_subgoal(request.auth, goal_id, sid, payload)


@router.delete("/{goal_id}/subgoals/{sid}", response={204: None}, summary="Delete subgoal")
def delete_sub(request, goal_id: str, sid: str):
    delete_subgoal(request.auth, goal_id, sid)
    return 204, None


# --- Goal-Account links ---

@router.post("/{goal_id}/accounts", response={201: GoalAccountOut}, summary="Link account to goal")
def link_acc(request, goal_id: str, payload: GoalAccountIn):
    return 201, link_account(request.auth, goal_id, str(payload.account_id))


@router.delete(
    "/{goal_id}/accounts/{account_id}", response={204: None}, summary="Unlink account from goal"
)
def unlink_acc(request, goal_id: str, account_id: str):
    unlink_account(request.auth, goal_id, account_id)
    return 204, None
