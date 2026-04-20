# Link Accounts to Goals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to link accounts to goal allocations, automatically deducting from account balance and updating goal progress via database triggers.

**Architecture:** Database-centric synchronization using PostgreSQL triggers to maintain data integrity between ledger entries (allocations) and state tables (accounts/goals).

**Tech Stack:** Supabase (PostgreSQL), Flutter (Dart, BLoC).

---

### Task 1: Database Schema & Trigger Logic

**Files:**
- Create: `backend/supabase/migrations/20260421000000_link_accounts_to_goals.sql`

- [ ] **Step 1: Write migration for schema and trigger**

```sql
-- 1. Add account_id and sub_goal_id to goal_allocations
ALTER TABLE public.goal_allocations 
ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
ADD COLUMN sub_goal_id uuid REFERENCES public.sub_goals(id) ON DELETE SET NULL;

CREATE INDEX idx_goal_allocations_account_id ON public.goal_allocations(account_id);
CREATE INDEX idx_goal_allocations_sub_goal_id ON public.goal_allocations(sub_goal_id);

-- 2. Add sanity check for account balance
ALTER TABLE public.accounts ADD CONSTRAINT accounts_balance_check CHECK (balance >= 0);

-- 3. Create function to sync balances (Handles Insert, Update, Delete)
CREATE OR REPLACE FUNCTION public.sync_allocation_balances()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle Account Balance Sync
  IF TG_OP = 'INSERT' THEN
    IF NEW.account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance - NEW.amount 
      WHERE id = NEW.account_id AND user_id = NEW.user_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance + OLD.amount 
      WHERE id = OLD.account_id AND user_id = OLD.user_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Revert old amount, apply new amount
    IF OLD.account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance + OLD.amount 
      WHERE id = OLD.account_id AND user_id = OLD.user_id;
    END IF;
    IF NEW.account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance - NEW.amount 
      WHERE id = NEW.account_id AND user_id = NEW.user_id;
    END IF;
  END IF;

  -- Handle Goal/SubGoal Progress Sync
  IF TG_OP = 'INSERT' THEN
    IF NEW.sub_goal_id IS NOT NULL THEN
      UPDATE public.sub_goals SET current_amount = current_amount + NEW.amount 
      WHERE id = NEW.sub_goal_id AND user_id = NEW.user_id;
    ELSE
      UPDATE public.goals SET current_amount = current_amount + NEW.amount 
      WHERE id = NEW.goal_id AND user_id = NEW.user_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.sub_goal_id IS NOT NULL THEN
      UPDATE public.sub_goals SET current_amount = current_amount - OLD.amount 
      WHERE id = OLD.sub_goal_id AND user_id = OLD.user_id;
    ELSE
      UPDATE public.goals SET current_amount = current_amount - OLD.amount 
      WHERE id = OLD.goal_id AND user_id = OLD.user_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Revert old progress
    IF OLD.sub_goal_id IS NOT NULL THEN
      UPDATE public.sub_goals SET current_amount = current_amount - OLD.amount 
      WHERE id = OLD.sub_goal_id AND user_id = OLD.user_id;
    ELSE
      UPDATE public.goals SET current_amount = current_amount - OLD.amount 
      WHERE id = OLD.goal_id AND user_id = OLD.user_id;
    END IF;
    -- Apply new progress
    IF NEW.sub_goal_id IS NOT NULL THEN
      UPDATE public.sub_goals SET current_amount = current_amount + NEW.amount 
      WHERE id = NEW.sub_goal_id AND user_id = NEW.user_id;
    ELSE
      UPDATE public.goals SET current_amount = current_amount + NEW.amount 
      WHERE id = NEW.goal_id AND user_id = NEW.user_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create trigger
DROP TRIGGER IF EXISTS trigger_sync_allocation_balances ON public.goal_allocations;
CREATE TRIGGER trigger_sync_allocation_balances
AFTER INSERT OR UPDATE OR DELETE ON public.goal_allocations
FOR EACH ROW EXECUTE FUNCTION public.sync_allocation_balances();
```

- [ ] **Step 2: Apply migration locally**

Run: `cd backend && supabase migration up`
Expected: Success.

- [ ] **Step 3: Verify trigger with a manual SQL insert**

Run:
```sql
-- Insert a test allocation linked to an account
INSERT INTO public.goal_allocations (user_id, goal_id, account_id, amount)
VALUES ('YOUR_USER_ID', 'YOUR_GOAL_ID', 'YOUR_ACCOUNT_ID', 50.00);
```
Expected: `accounts.balance` decreases by 50, `goals.current_amount` increases by 50.

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/migrations/
git commit -m "db: add account_id to allocations and balance sync trigger"
```

### Task 2: Data Model & Repository Updates

**Files:**
- Modify: `frontend/lib/features/goals/models/allocation.dart`
- Modify: `frontend/lib/features/goals/repositories/goal_repository.dart`

- [ ] **Step 1: Update GoalAllocation model**

```dart
// Modify: frontend/lib/features/goals/models/allocation.dart
class GoalAllocation {
  final String id;
  final String userId;
  final String goalId;
  final String? goalName;
  final String? accountId; // New
  final String? accountName; // New (from join)
  final String? subGoalId; // New
  final double amount;
  final DateTime createdAt;

  GoalAllocation({
    required this.id,
    required this.userId,
    required this.goalId,
    this.goalName,
    this.accountId,
    this.accountName,
    this.subGoalId,
    required this.amount,
    required this.createdAt,
  });

  factory GoalAllocation.fromJson(Map<String, dynamic> json) {
    return GoalAllocation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      goalId: json['goal_id'] as String,
      goalName: json['goals'] != null ? json['goals']['name'] as String? : null,
      accountId: json['account_id'] as String?,
      accountName: json['accounts'] != null ? json['accounts']['name'] as String? : null,
      subGoalId: json['sub_goal_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_id': goalId, 
      'amount': amount,
      if (accountId != null) 'account_id': accountId,
      if (subGoalId != null) 'sub_goal_id': subGoalId,
    };
  }
}
```

- [ ] **Step 2: Update GoalRepository.insertAllocation**

```dart
// Modify: frontend/lib/features/goals/repositories/goal_repository.dart
Future<void> insertAllocation(String goalId, double amount, {String? accountId, String? subGoalId}) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw Exception('User not logged in');

  await supabase.from('goal_allocations').insert({
    'user_id': userId,
    'goal_id': goalId,
    'amount': amount,
    if (accountId != null) 'account_id': accountId,
    if (subGoalId != null) 'sub_goal_id': subGoalId,
  });
}

// Update getAllocations to fetch account name
Future<List<GoalAllocation>> getAllocations() async {
  final response = await supabase
      .from('goal_allocations')
      .select('*, goals(name), accounts(name)') // Updated join
      .order('created_at', ascending: false);
  return (response as List).map((e) => GoalAllocation.fromJson(e)).toList();
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/goals/
git commit -m "feat: update goal allocation models and repository for accounts"
```

### Task 3: UI Integration in OverviewTab

**Files:**
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Add Account Selector to Manual Allocation Dialog**

```dart
// Modify: frontend/lib/features/dashboard/presentation/screens/overview_tab.dart
// Inside _showManualAllocation(List<Goal> goals)

Account? selectedAccount; // New variable
// Fetch accounts from DashboardDataLoaded state (available in context)

// Inside showDialog StatefulBuilder:
DropdownButtonFormField<Account>(
  value: selectedAccount,
  decoration: const InputDecoration(
    labelText: 'Source Account (Optional)',
    helperText: 'Funds will be deducted from this account',
  ),
  items: [
    const DropdownMenuItem(value: null, child: Text('None (Manual Entry)')),
    ...accounts.map((a) => DropdownMenuItem(
      value: a,
      child: Text('${a.name} (\$${a.balance.toStringAsFixed(2)})'),
    )),
  ],
  onChanged: (val) => setDialogState(() => selectedAccount = val),
),
```

- [ ] **Step 2: Update Recent Activity to show Source Account**

```dart
// Inside _buildRecentActivity item builder
Text(
  allocation.accountName != null 
    ? 'from ${allocation.accountName}' 
    : 'Manual Entry',
  style: Theme.of(context).textTheme.labelSmall,
),
```

- [ ] **Step 3: Run static analysis and tests**

Run: `flutter analyze && flutter test`
Expected: PASS.

- [ ] **Step 4: Commit and Finish**

```bash
git add frontend/lib/features/dashboard/
git commit -m "ui: integrate account selection in goal allocation dialog"
```
