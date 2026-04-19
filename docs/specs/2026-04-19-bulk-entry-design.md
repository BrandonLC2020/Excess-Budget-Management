# Bulk Expense and Income Entry UI Design

## Objective
Implement a bulk entry system for adding multiple expense transactions and income sources simultaneously, improving user efficiency and reducing repetitive form submissions.

## Architecture & State Management (Approach 2)
We will follow a strict Feature-First Architecture using Feature-Specific State Management:
*   **Unified UI Shell**: A new screen, `BulkEntryScreen`, will serve as a unified shell containing two tabs: "Expenses" and "Income".
*   **Feature Separation**: 
    *   The "Expenses" tab will be powered by a new `BulkExpensesBloc` located in `features/budget/bloc/`.
    *   The "Income" tab will be powered by a new `BulkIncomeBloc` located in `features/income/bloc/`.
*   **Navigation**: This unified screen will be accessible via a global action (e.g., from the Dashboard FAB).

## Database Schema Updates
To support individual expense transactions, a new migration will be created for an `expenses` table:
*   **`expenses` table**: 
    *   `id` (uuid, primary key)
    *   `user_id` (uuid, foreign key to `profiles`)
    *   `budget_category_id` (uuid, foreign key to `budget_categories`)
    *   `amount` (numeric)
    *   `description` (text)
    *   `date` (date)
    *   `created_at` (timestamp)
*   **Income**: We will utilize the existing `extra_income` table for bulk one-off income entries.

## Backend Integration & Validation
*   **Bulk Insert**: Repositories will use Supabase's `.insert([...list])` capabilities.
*   **Validation Strategy**: We will prioritize a balance of DB security and good UX by performing strict client-side validation on all rows before enabling the "Save All" button. If the bulk insert fails at the database level, the entire batch fails (Atomic), and an error message is shown to the user, allowing them to correct and retry.

## UI / UX Design
*   **Adaptive Layout**: 
    *   **Wide Screens (Tablet/Desktop)**: Rows will be displayed in a Data Table format for spreadsheet-like rapid data entry.
    *   **Narrow Screens (Mobile)**: Rows will be displayed as a Dynamic List of cards to prevent horizontal scrolling issues and maintain touch targets (>= 48x48).
*   **Interactions**: Users can add new blank rows, delete rows, and edit fields (Amount, Category/Source, Date, Description) inline.

## Testing Strategy
*   **Bloc Tests**: Verify that adding, updating, and removing rows updates the state correctly, and that validation logic works.
*   **Widget Tests**: Verify the adaptive layout switches between Data Table and List views based on screen width.

## Scope
This design is well-bounded to the bulk entry feature and requires creating the new `expenses` table, the UI shell, the two specific Blocs, and updating the repositories to handle lists.
