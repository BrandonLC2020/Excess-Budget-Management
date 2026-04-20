# Design Spec: Link Accounts to Goals for Funding Tracking

## Overview
This feature allows users to associate specific financial accounts with goal allocations. This enables automatic tracking of where goal funds are sourced from and ensures account balances are synchronized with goal progress.

## User Experience

### 1. Goal Allocation Dialog Updates
*   **Source Account Selector**: A new `DropdownButtonFormField` in the "Allocate Funds" dialog allowing users to select an existing account (e.g., "Savings", "Checking").
*   **Balance Validation**: The dialog will display the selected account's current balance and prevent users from allocating more than the available amount.
*   **Optional Source**: Users can choose "None (Manual Entry)" to record goal progress without affecting any specific account balance (e.g., for cash gifts or external transfers).

### 2. Recent Activity Enhancements
*   **Funding Source Attribution**: Each entry in the "Recent Activity" list will display the name of the source account (e.g., "$100.00 to 'Emergency Fund' from 'Main Savings'").
*   **Visual Indicators**: Use account-specific icons in the activity list to distinguish between different funding sources.

## Technical Architecture

### 1. Database Layer (Supabase/PostgreSQL)
*   **Schema Update**: Add `account_id` (UUID, nullable) to the `goal_allocations` table with a foreign key constraint to `accounts.id`.
*   **Automated Synchronization (Trigger)**:
    *   Create a PostgreSQL function `sync_allocation_balances()` triggered `AFTER INSERT` on `goal_allocations`.
    *   **Logic**:
        1.  If `account_id` is present, decrement the `balance` in `accounts` by the allocation `amount`.
        2.  Increment the `current_amount` in `goals` by the allocation `amount` (maintaining current behavior but ensuring consistency).
        3.  Validation: Ensure the account balance doesn't drop below zero (if applicable).

### 2. Data Layer (Flutter/Dart)
*   **Model Update**: Add `accountId` and `accountName` (optional join field) to the `GoalAllocation` model.
*   **Repository Update**:
    *   `GoalRepository.createAllocation()`: Updated to accept the optional `accountId`.
    *   `AccountRepository.getAccounts()`: Ensure accounts are fetched with up-to-date balances for the selector.

### 3. Presentation Layer (BLoC/UI)
*   **DashboardBloc**: Ensure the `DashboardDataLoaded` state includes the necessary account information to populate the allocation dialog.
*   **Validation Logic**: Add client-side validation in the dialog to prevent over-allocation based on the selected account's balance.

## Verification Plan

### 1. Automated Tests
*   **Unit Tests**: Verify `GoalAllocation` JSON serialization with the new `accountId` field.
*   **Widget Tests**: Confirm the Account dropdown appears in the allocation dialog and correctly filters/validates based on balance.
*   **Integration Tests (Supabase)**: Verify that inserting a `goal_allocation` via the API correctly updates the `accounts` table balance via the trigger.

### 2. Manual Verification
*   Create an allocation from a specific account and verify the account balance decreases.
*   Verify that "Manual Entry" (no account) still increments goal progress without affecting any accounts.
*   Confirm the "Recent Activity" list on the dashboard correctly displays the account name.
