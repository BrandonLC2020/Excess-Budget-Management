# Live Sync for Budget and Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement real-time synchronization between the database and the UI for budget categories and account balances using Supabase Realtime.

**Architecture:** We will update `BudgetRepository` and `AccountRepository` to expose `Stream<List<T>>` using Supabase's `.stream()` API. The `BudgetBloc` and `AccountBloc` will be refactored to listen to these streams and emit state updates reactively.

**Tech Stack:** Flutter, BLoC, Supabase Realtime.

---

### Task 1: Update Repositories with Stream Methods

**Files:**
- Modify: `frontend/lib/features/budget/repositories/budget_repository.dart`
- Modify: `frontend/lib/features/accounts/repositories/account_repository.dart`

- [ ] **Step 1: Add `getBudgetCategoriesStream` to `BudgetRepository`**

```dart
// frontend/lib/features/budget/repositories/budget_repository.dart

  Stream<List<BudgetCategory>> getBudgetCategoriesStream() {
    return supabase
        .from('budget_categories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => BudgetCategory.fromJson(e)).toList());
  }
```

- [ ] **Step 2: Add `getAccountsStream` to `AccountRepository`**

```dart
// frontend/lib/features/accounts/repositories/account_repository.dart

  Stream<List<Account>> getAccountsStream() {
    return supabase
        .from('accounts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => Account.fromJson(e)).toList());
  }
```

- [ ] **Step 3: Commit Repository changes**

```bash
git add frontend/lib/features/budget/repositories/budget_repository.dart frontend/lib/features/accounts/repositories/account_repository.dart
git commit -m "feat: add real-time stream methods to budget and account repositories"
```

---

### Task 2: Refactor BudgetBloc to use Streams

**Files:**
- Modify: `frontend/lib/features/budget/bloc/budget_bloc.dart`
- Test: `frontend/test/features/budget/bloc/budget_bloc_test.dart` (Check if exists, if not create)

- [ ] **Step 1: Update `BudgetBloc` with StreamSubscription**

```dart
// frontend/lib/features/budget/bloc/budget_bloc.dart

import 'dart:async'; // Add this import

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final BudgetRepository repository;
  StreamSubscription<List<BudgetCategory>>? _subscription;

  BudgetBloc({required this.repository}) : super(BudgetInitial()) {
    on<LoadBudgets>((event, emit) async {
      emit(BudgetLoading());
      await _subscription?.cancel();
      _subscription = repository.getBudgetCategoriesStream().listen(
        (categories) {
          add(_UpdateBudgets(categories));
        },
        onError: (e) {
          add(_HandleBudgetError(e.toString()));
        },
      );
    });

    // Internal events for stream handling
    on<_UpdateBudgets>((event, emit) {
      emit(BudgetLoaded(event.categories));
    });

    on<_HandleBudgetError>((event, emit) {
      emit(BudgetError(event.message));
    });

    // ... handle other events (Add/Update/Delete) ...
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

// Add these internal events to the bottom of the file (private)
class _UpdateBudgets extends BudgetEvent {
  final List<BudgetCategory> categories;
  const _UpdateBudgets(this.categories);
  @override
  List<Object?> get props => [categories];
}

class _HandleBudgetError extends BudgetEvent {
  final String message;
  const _HandleBudgetError(this.message);
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 2: Update existing event handlers to remove manual `LoadBudgets` calls**
Since the stream will automatically push updates after a database write, we no longer need to manually trigger `LoadBudgets` inside `AddBudgetCategory`, `UpdateBudgetCategory`, or `DeleteBudgetCategory`.

- [ ] **Step 3: Write and run TDD tests**
Verify that `BudgetBloc` emits `BudgetLoaded` when the stream pushes data.

- [ ] **Step 4: Commit BudgetBloc changes**

```bash
git add frontend/lib/features/budget/bloc/budget_bloc.dart
git commit -m "feat: refactor BudgetBloc to use real-time streams"
```

---

### Task 3: Refactor AccountBloc to use Streams

**Files:**
- Modify: `frontend/lib/features/accounts/bloc/account_bloc.dart`
- Test: `frontend/test/features/accounts/bloc/account_bloc_test.dart`

- [ ] **Step 1: Update `AccountBloc` with StreamSubscription**

```dart
// frontend/lib/features/accounts/bloc/account_bloc.dart

import 'dart:async';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final AccountRepository repository;
  StreamSubscription<List<Account>>? _subscription;

  AccountBloc({required this.repository}) : super(AccountInitial()) {
    on<LoadAccounts>((event, emit) async {
      emit(AccountLoading());
      await _subscription?.cancel();
      _subscription = repository.getAccountsStream().listen(
        (accounts) {
          add(_UpdateAccounts(accounts));
        },
        onError: (e) {
          add(_HandleAccountError(e.toString()));
        },
      );
    });

    on<_UpdateAccounts>((event, emit) {
      emit(AccountLoaded(event.accounts));
    });

    on<_HandleAccountError>((event, emit) {
      emit(AccountError(event.message));
    });

    // ... update Add/Update/Delete handlers to remove manual LoadAccounts() ...
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class _UpdateAccounts extends AccountEvent {
  final List<Account> accounts;
  const _UpdateAccounts(this.accounts);
  @override
  List<Object?> get props => [accounts];
}

class _HandleAccountError extends AccountEvent {
  final String message;
  const _HandleAccountError(this.message);
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 2: Write and run TDD tests**

- [ ] **Step 3: Commit AccountBloc changes**

```bash
git add frontend/lib/features/accounts/bloc/account_bloc.dart
git commit -m "feat: refactor AccountBloc to use real-time streams"
```

---

### Task 4: Final Verification

- [ ] **Step 1: Run all tests**
Run `flutter test` in `frontend/` directory.

- [ ] **Step 2: Run app and verify behavior**
Manual verification using the Bulk Entry feature.
