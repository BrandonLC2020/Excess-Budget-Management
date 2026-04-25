# Specification: Income-Budget Category Integration

## Overview
This feature allows users to link income entries to budget categories. It supports two primary use cases:
1. **Savings Targets:** Tracking progress toward a specific income or savings goal (e.g., "Minimum Savings").
2. **Expense Offsets:** Using income to offset spending in an expense category (e.g., a refund or reimbursement).

## Architecture

### Database Schema Changes (Supabase/PostgreSQL)

#### 1. `budget_categories` Table
- Add `category_type` column:
  - Type: `text` (or enum if preferred)
  - Values: `'expense'`, `'income'`
  - Default: `'expense'`
- Purpose: Distinguishes between categories meant for limiting spending and those meant for tracking income/savings targets.

#### 2. `extra_income` Table
- Add `budget_category_id` column:
  - Type: `uuid` (Foreign Key to `budget_categories.id`)
  - Nullable: `true`
- Purpose: Links an individual income entry to a budget category.

#### 3. Automation (Triggers)
- New trigger `trigger_update_budget_from_income` on `extra_income`:
  - **On INSERT:**
    - If linked category is `income`: Increment `spent_amount` (tracking progress toward target).
    - If linked category is `expense`: Decrement `spent_amount` (offsetting expenses).
  - **On DELETE/UPDATE:** Similar logic to maintain balance consistency.

### Frontend Changes (Flutter)

#### 1. Models
- **`BudgetCategory`**:
  - Add `BudgetCategoryType` enum.
  - Update `fromJson` and `toJson` to handle the new `type` field.
- **`Income`**:
  - Add `categoryId` field.
  - Update serialization logic.

#### 2. BLoC Logic
- **`BulkIncomeBloc`**:
  - Update `IncomeRow` to include `categoryId`.
  - Add `categoryId` parameter to `UpdateIncomeRow` event.
  - Fetch/Observe `BudgetBloc` to provide a list of categories for the UI.
- **`BudgetBloc`**:
  - Handle the new `category_type` field during creation and updates.

#### 3. UI Components
- **`BulkIncomeTab`**:
  - Add a "Budget Category" dropdown for each income row.
  - Display category name and type indicator.
- **`BudgetCategoryFormSheet`**:
  - Add a type selector (Expense vs. Income) with descriptive labels.
- **`BudgetCategoryCard`**:
  - Adapt labels based on type:
    - Expense: "Spent of $[limit]"
    - Income: "Saved of $[limit]" (treated as target)
  - Color styling: Use green themes for income progress.

## Success Criteria
- Users can create "Income" type budget categories.
- Users can select a budget category when logging income (bulk or single).
- Linking income to an "Income" category increases its progress.
- Linking income to an "Expense" category decreases its "spent" total.
- The budget screen correctly labels and colors categories based on their type.

## Testing Strategy
- **Database:** Unit tests for triggers ensuring correct balance arithmetic for both types.
- **Models:** Serialization tests for new fields.
- **UI:** 
  - Verify dropdown contains all user categories.
  - Verify budget card labels change correctly.
- **Integration:** End-to-end flow from logging income with a category to verifying the budget category balance update.
