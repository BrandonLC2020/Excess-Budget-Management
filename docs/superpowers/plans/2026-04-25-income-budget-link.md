# Income-Budget Category Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable linking income entries to budget categories to support savings targets and expense offsets.

**Architecture:** 
- Add `category_type` to `budget_categories` and `budget_category_id` to `extra_income`.
- Implement a PostgreSQL trigger to automate balance updates based on the category type (Income vs. Expense).
- Update the Flutter frontend (models, BLoC, and UI) to support these fields and provide a visual distinction in the budget overview.

**Tech Stack:** Flutter, Dart, Supabase (PostgreSQL), flutter_bloc, go_router.

---

## File Mapping

### Backend (Supabase)
- `backend/supabase/migrations/20260425000000_income_budget_integration.sql`: New migration for schema changes and triggers.

### Frontend (Flutter)
- `frontend/lib/features/budget/models/budget_category.dart`: Add `category_type`.
- `frontend/lib/features/income/models/income.dart`: Add `category_id`.
- `frontend/lib/features/income/bloc/bulk_income_bloc.dart`: Update state and events to handle `categoryId`.
- `frontend/lib/features/income/presentation/widgets/bulk_income_tab.dart`: Add category dropdown.
- `frontend/lib/features/budget/presentation/widgets/budget_category_form_sheet.dart`: Add type selector.
- `frontend/lib/features/budget/presentation/widgets/budget_category_card.dart`: Adapt UI for income types.

---

## Tasks

### Task 1: Backend Schema Migration

**Files:**
- Create: `backend/supabase/migrations/20260425000000_income_budget_integration.sql`

- [ ] **Step 1: Define migration for schema and triggers**

```sql
-- Create enum for category type
DO $$ BEGIN
    CREATE TYPE public.category_type AS ENUM ('expense', 'income');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add category_type to budget_categories
ALTER TABLE public.budget_categories 
ADD COLUMN IF NOT EXISTS category_type public.category_type DEFAULT 'expense';

-- Add budget_category_id to extra_income
ALTER TABLE public.extra_income 
ADD COLUMN IF NOT EXISTS budget_category_id uuid REFERENCES public.budget_categories(id) ON DELETE SET NULL;

-- Trigger function to update budget balance from income
CREATE OR REPLACE FUNCTION public.handle_income_budget_update()
RETURNS TRIGGER AS $$
DECLARE
    v_cat_type public.category_type;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.budget_category_id IS NOT NULL THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount + NEW.amount WHERE id = NEW.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount - NEW.amount WHERE id = NEW.budget_category_id;
            END IF;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.budget_category_id IS NOT NULL THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = OLD.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount WHERE id = OLD.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount WHERE id = OLD.budget_category_id;
            END IF;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle category change
        IF OLD.budget_category_id IS NOT NULL THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = OLD.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount WHERE id = OLD.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount WHERE id = OLD.budget_category_id;
            END IF;
        END IF;
        IF NEW.budget_category_id IS NOT NULL THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount + NEW.amount WHERE id = NEW.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount - NEW.amount WHERE id = NEW.budget_category_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_income_budget_update ON public.extra_income;
CREATE TRIGGER trigger_income_budget_update
AFTER INSERT OR UPDATE OR DELETE ON public.extra_income
FOR EACH ROW EXECUTE FUNCTION public.handle_income_budget_update();
```

- [ ] **Step 2: Apply migration**

Run: `cd backend && supabase migration up`

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260425000000_income_budget_integration.sql
git commit -m "feat: add income-budget integration schema and triggers"
```

### Task 2: Update Data Models

**Files:**
- Modify: `frontend/lib/features/budget/models/budget_category.dart`
- Modify: `frontend/lib/features/income/models/income.dart`

- [ ] **Step 1: Update BudgetCategory model**

```dart
enum BudgetCategoryType { expense, income }

class BudgetCategory {
  // ... existing fields
  final BudgetCategoryType type;

  BudgetCategory({
    // ... existing params
    this.type = BudgetCategoryType.expense,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      // ... existing mappings
      type: json['category_type'] == 'income' 
          ? BudgetCategoryType.income 
          : BudgetCategoryType.expense,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // ... existing mappings
      'category_type': type.name,
    };
  }
}
```

- [ ] **Step 2: Update Income model**

```dart
class Income {
  // ... existing fields
  final String? categoryId;

  Income({
    // ... existing params
    this.categoryId,
  });

  factory Income.fromJson(Map<String, dynamic> json) => Income(
    // ... existing mappings
    categoryId: json['budget_category_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    // ... existing mappings
    'budget_category_id': categoryId,
  };
}
```

- [ ] **Step 3: Regenerate serialization code**

Run: `cd frontend && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/budget/models/budget_category.dart frontend/lib/features/income/models/income.dart
git commit -m "feat: update budget and income models for category integration"
```

### Task 3: Update BulkIncome BLoC

**Files:**
- Modify: `frontend/lib/features/income/bloc/bulk_income_bloc.dart`
- Modify: `frontend/lib/features/income/bloc/bulk_income_event.dart`
- Modify: `frontend/lib/features/income/bloc/bulk_income_state.dart`

- [ ] **Step 1: Update IncomeRow and Events**
Update `IncomeRow` class in `bulk_income_state.dart` to include `categoryId`.
Update `UpdateIncomeRow` event in `bulk_income_event.dart` to include `categoryId`.

- [ ] **Step 2: Update Bloc logic to handle category selection**
Modify `_onUpdateIncomeRow` in `bulk_income_bloc.dart` to update the state with the new `categoryId`.
Modify `_onSubmitBulkIncome` to include `budget_category_id` in the repository call.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/income/bloc/
git commit -m "feat: update BulkIncomeBloc to handle category selection"
```

### Task 4: UI Integration - Income Entry

**Files:**
- Modify: `frontend/lib/features/income/presentation/widgets/bulk_income_tab.dart`

- [ ] **Step 1: Add category dropdown to BulkIncomeTab**
Wrap the dropdown in a `BlocBuilder<BudgetBloc, BudgetState>` to fetch categories.
Add `DropdownButtonFormField<String>` to select a budget category.

- [ ] **Step 2: Commit**

```bash
git add frontend/lib/features/income/presentation/widgets/bulk_income_tab.dart
git commit -m "feat: add budget category selection to income entry"
```

### Task 5: UI Integration - Budget Management

**Files:**
- Modify: `frontend/lib/features/budget/presentation/widgets/budget_category_form_sheet.dart`
- Modify: `frontend/lib/features/budget/presentation/widgets/budget_category_card.dart`

- [ ] **Step 1: Add type selector to category form**
Add a `SegmentedButton<BudgetCategoryType>` or similar to `BudgetCategoryFormSheet`.

- [ ] **Step 2: Update category card labels**
Modify `BudgetCategoryCard` to use "Saved" instead of "Spent" and "Target" instead of "Limit" for income types.
Use a green progress bar for income categories.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/budget/presentation/widgets/
git commit -m "feat: enhance budget UI for income-type categories"
```
