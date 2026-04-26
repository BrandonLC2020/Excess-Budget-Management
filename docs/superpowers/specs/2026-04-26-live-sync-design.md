# Design Spec: Live Sync for Budget and Accounts (ClickUp 86b9m4jj8)

**Goal:** Ensure that new transactions (expenses/income) entered via Bulk Entry or any other method immediately update Account balances and Budget Category spending across the app without manual refresh.

## Background
Currently, `BudgetBloc` and `AccountBloc` fetch data once on initialization using `Future`-based methods in their respective repositories. While the database has triggers to update `spent_amount` (in `budget_categories`) and `balance` (in `accounts`) when transactions occur, these changes are not pushed to the frontend.

## Proposed Architecture

We will implement **Option B: Realtime Subscription**. We will leverage Supabase Realtime to listen for changes on the "source of truth" tables (`budget_categories` and `accounts`).

### 1. Data Flow
1. User adds an expense via `BulkExpensesBloc`.
2. Supabase `expenses` table receives a new row.
3. Database Trigger `trigger_update_budget_spent` updates the `spent_amount` in the corresponding `budget_categories` row.
4. Database Trigger `trigger_expense_balance` updates the `balance` in the corresponding `accounts` row.
5. Supabase Realtime detects changes in `budget_categories` and `accounts`.
6. `BudgetRepository` and `AccountRepository` streams receive the updated list of rows.
7. `BudgetBloc` and `AccountBloc` (listening to these streams) emit new `Loaded` states.
8. Flutter UI rebuilds instantly with the new values.

## Component Specifications

### 1. Repositories (`frontend/lib/features/...`)

#### BudgetRepository
- **New Method**: `Stream<List<BudgetCategory>> getBudgetCategoriesStream()`
- **Implementation**:
  ```dart
  Stream<List<BudgetCategory>> getBudgetCategoriesStream() {
    return supabase
        .from('budget_categories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => BudgetCategory.fromJson(e)).toList());
  }
  ```

#### AccountRepository
- **New Method**: `Stream<List<Account>> getAccountsStream()`
- **Implementation**:
  ```dart
  Stream<List<Account>> getAccountsStream() {
    return supabase
        .from('accounts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => Account.fromJson(e)).toList());
  }
  ```

### 2. BLoCs (`frontend/lib/features/...`)

#### BudgetBloc
- **Change**: Replace one-time fetch with stream listening.
- **State Management**:
  - Add `StreamSubscription<List<BudgetCategory>>? _subscription`.
  - In constructor or via `LoadBudgets` event, start listening.
  - On data: `emit(BudgetLoaded(categories))`.
  - On error: `emit(BudgetError(e.toString()))`.
  - **Lifecycle**: Override `close()` to cancel `_subscription`.

#### AccountBloc
- **Change**: Replace one-time fetch with stream listening.
- **State Management**:
  - Add `StreamSubscription<List<Account>>? _subscription`.
  - On data: `emit(AccountLoaded(accounts))`.
  - **Lifecycle**: Override `close()` to cancel `_subscription`.

## Testing & Verification

### Unit Tests
- Mock repositories using `mocktail`.
- Use `StreamController` to verify that when the stream pushes data, the BLoC emits the correct state.

### Manual Verification
1. Open the Budget Screen.
2. Open Bulk Entry in a separate tab or device (or side-by-side).
3. Add an expense.
4. Verify the spending bar in the Budget Screen updates immediately.

## Error Handling
- Use `onError` in `Stream.listen` to handle network interruptions or parsing failures.
- Ensure `BudgetLoading` is emitted only on the initial connection, while subsequent updates silently refresh the list or handle errors gracefully.
