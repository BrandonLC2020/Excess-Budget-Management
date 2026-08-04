from apps.common.firestore import get_client
from apps.common.rollups import (
    apply_expense_effects,
    apply_extra_income_effects,
    recompute_subgoal_parent,
    recompute_goal_from_accounts,
    apply_allocation_effects,
)


def _seed_account(account_id, balance_cents):
    get_client().collection("accounts").document(account_id).set({"balance": balance_cents})


def _seed_category(category_id, category_type, spent_cents=0):
    get_client().collection("budget_categories").document(category_id).set(
        {"category_type": category_type, "spent_amount": spent_cents}
    )


def test_apply_expense_effects_on_create_debits_balance_and_credits_spent():
    _seed_account("acc1", 10000)
    _seed_category("cat1", "expense", 0)

    apply_expense_effects(
        old=None, new={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 3000}
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 7000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 3000


def test_apply_expense_effects_against_income_category_flips_sign():
    _seed_category("cat1", "income", 0)

    apply_expense_effects(
        old=None, new={"account_id": None, "budget_category_id": "cat1", "amount_cents": 5000}
    )

    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == -5000


def test_apply_expense_effects_on_delete_reverses():
    _seed_account("acc1", 7000)
    _seed_category("cat1", "expense", 3000)

    apply_expense_effects(
        old={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 3000}, new=None
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 10000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 0


def test_apply_expense_effects_on_update_reverses_old_and_applies_new():
    _seed_account("acc1", 7000)
    _seed_category("cat1", "expense", 3000)

    apply_expense_effects(
        old={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 3000},
        new={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 5000},
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 5000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 5000


def test_apply_extra_income_effects_credits_balance_and_budget():
    _seed_account("acc1", 10000)
    _seed_category("cat1", "income", 0)

    apply_extra_income_effects(
        old=None, new={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 5000}
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 15000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 5000


def test_recompute_subgoal_parent_sums_siblings():
    get_client().collection("goals").document("g1").set({"target_amount": 0, "current_amount": 0})
    get_client().collection("sub_goals").document("s1").set(
        {"goal_id": "g1", "target_amount": 50000, "current_amount": 10000}
    )
    get_client().collection("sub_goals").document("s2").set(
        {"goal_id": "g1", "target_amount": 70000, "current_amount": 0}
    )

    recompute_subgoal_parent("g1")

    goal = get_client().collection("goals").document("g1").get()
    assert goal.get("target_amount") == 120000
    assert goal.get("current_amount") == 10000


def test_recompute_subgoal_parent_noop_when_no_subgoals():
    get_client().collection("goals").document("g2").set({"target_amount": 999, "current_amount": 999})

    recompute_subgoal_parent("g2")

    goal = get_client().collection("goals").document("g2").get()
    assert goal.get("target_amount") == 999


def test_recompute_goal_from_accounts_sums_linked_balances():
    get_client().collection("goals").document("g1").set({"current_amount": 0})
    _seed_account("a1", 30000)
    _seed_account("a2", 40000)
    get_client().collection("goal_accounts").document("g1_a1").set({"goal_id": "g1", "account_id": "a1"})
    get_client().collection("goal_accounts").document("g1_a2").set({"goal_id": "g1", "account_id": "a2"})

    recompute_goal_from_accounts("g1")

    assert get_client().collection("goals").document("g1").get().get("current_amount") == 70000


def test_apply_allocation_effects_debits_account_credits_goal():
    _seed_account("acc1", 50000)
    get_client().collection("goals").document("g1").set({"current_amount": 0})

    apply_allocation_effects(
        old=None, new={"account_id": "acc1", "goal_id": "g1", "sub_goal_id": None, "amount_cents": 20000}
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 30000
    assert get_client().collection("goals").document("g1").get().get("current_amount") == 20000


def test_apply_allocation_effects_credits_subgoal_and_rolls_up_to_parent():
    get_client().collection("goals").document("g1").set({"target_amount": 50000, "current_amount": 0})
    get_client().collection("sub_goals").document("s1").set(
        {"goal_id": "g1", "target_amount": 50000, "current_amount": 0}
    )

    apply_allocation_effects(
        old=None, new={"account_id": None, "goal_id": "g1", "sub_goal_id": "s1", "amount_cents": 10000}
    )

    assert get_client().collection("sub_goals").document("s1").get().get("current_amount") == 10000
    assert get_client().collection("goals").document("g1").get().get("current_amount") == 10000


def test_apply_allocation_effects_on_delete_reverses():
    _seed_account("acc1", 30000)
    get_client().collection("goals").document("g1").set({"current_amount": 20000})

    apply_allocation_effects(
        old={"account_id": "acc1", "goal_id": "g1", "sub_goal_id": None, "amount_cents": 20000}, new=None
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 50000
    assert get_client().collection("goals").document("g1").get().get("current_amount") == 0
