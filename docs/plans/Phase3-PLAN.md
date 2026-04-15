# Phase 3 - Subgoal Tracking & Aggregation: Implementation Plan

## Objective
Implement Phase 3: Subgoal Tracking & Aggregation, allowing users to break down large, categorical goals into specific, actionable line items (subgoals). The parent goal will serve as an aggregate container, with its `target_amount` and `current_amount` automatically calculated from its nested subgoals via database triggers.

## Background & Motivation
Users often have complex financial objectives (e.g., "Vacation" or "Tech Upgrade") that consist of multiple distinct purchases. Tracking these as a single flat goal makes it difficult to see progress on individual items. Phase 3 introduces a hierarchy where a "Composite Goal" is driven by its "Subgoals," providing both granular tracking and high-level progress visualization.

## Scope & Impact
- **Database (Supabase):**
    - Create `sub_goals` table with foreign key to `goals`.
    - Implement a PostgreSQL function and trigger to roll up totals to the parent goal.
    - Define RLS policies for secure user-specific access.
- **Backend (Edge Functions):**
    - Update the `generate-suggestions` function to include nested subgoals in the Gemini context.
    - Enhance the prompt to enable AI reasoning about specific subgoal line items.
- **Frontend (Flutter):**
    - Introduce `SubGoal` model and update `Goal` model to support nesting.
    - Update `GoalRepository` to fetch subgoals in a single join query.
    - Implement a new **Goal Detail Screen** for managing line items.
    - Create a **Funding Distribution UI** to handle payments to composite goals.

## Proposed Solution
-   **Database-Driven Aggregation:** Use PostgreSQL triggers (`calculate_parent_goal_totals`) to ensure that the parent goal's totals are always in sync with its subgoals, regardless of which client (Web, Mobile, or AI) modifies the data.
-   **AI Context Awareness:** Pass the subgoal hierarchy to Gemini so it can provide more personalized and encouraging reasoning (e.g., "This $50 finishes funding your 'New Headphones' subgoal!").
-   **Hybrid UI Support:** The frontend will detect if a goal has subgoals. If it does, the parent `target_amount` becomes read-only (derived), and the UI focuses on managing the individual line items.

## Alternatives Considered
-   **Frontend Aggregation:** Considered calculating totals on the Flutter side. Rejected because it leads to data inconsistency if the backend or AI modifies a subgoal without the frontend active.
-   **Subgoal IDs in Ledger:** Considered tracking allocations directly to subgoal IDs. Rejected to keep the core `goal_allocations` ledger simple and focused on the primary goal categories; sub-distribution is managed as a "view" of the parent goal's funds.

## Implementation Steps

### Phase 1: Database Schema & Triggers
1.  **Migration:** Create `backend/supabase/migrations/20260515000000_phase3_subgoals.sql`.
2.  **`sub_goals` Table:** Define columns: `id`, `goal_id`, `user_id`, `name`, `target_amount`, `current_amount`, `created_at`.
3.  **RLS Policies:** Add `SELECT`, `INSERT`, `UPDATE`, `DELETE` policies where `user_id = auth.uid()`.
4.  **Aggregation Function:**
    ```sql
    CREATE OR REPLACE FUNCTION calculate_parent_goal_totals() RETURNS TRIGGER AS $$
    BEGIN
      UPDATE public.goals
      SET 
        target_amount = (SELECT COALESCE(SUM(target_amount), 0) FROM public.sub_goals WHERE goal_id = NEW.goal_id),
        current_amount = (SELECT COALESCE(SUM(current_amount), 0) FROM public.sub_goals WHERE goal_id = NEW.goal_id)
      WHERE id = NEW.goal_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    ```
5.  **Trigger:** Bind to `AFTER INSERT OR UPDATE OR DELETE` on `sub_goals`.

### Phase 2: Backend AI Enhancement
1.  **Update `generate-suggestions`:**
    *   Modify the database query in the Edge Function (or the frontend payload) to include the `sub_goals` array.
    *   Update the Gemini System Prompt:
        *   "Users can now have subgoals within their main goals."
        *   "When suggesting an allocation, you can reference a specific subgoal in your reasoning to make it more actionable."
        *   "Format: Still output the parent `goal_id` for the transaction, but specify the subgoal in the `reason` string."

### Phase 3: Frontend Data Layer
1.  **Models:**
    *   Create `frontend/lib/features/goals/models/sub_goal.dart` with `fromJson`/`toJson`.
    *   Update `Goal` model in `frontend/lib/features/goals/models/goal.dart` to include `List<SubGoal>? subGoals`.
2.  **Repository:**
    *   Update `GoalRepository.fetchGoals` to use `.select('*, sub_goals(*)')`.
    *   Add `addSubGoal(SubGoal subgoal)`.
    *   Add `updateSubGoalAmount(String subGoalId, double amount)`.
    *   Add `deleteSubGoal(String subGoalId)`.

### Phase 4: Frontend UI/UX
1.  **Goal Detail Screen:**
    *   Create `GoalDetailScreen` accessible by tapping a goal card on the dashboard.
    *   Show aggregate progress bar + list of subgoals with individual progress.
    *   Add "Add Subgoal" form.
2.  **Funding Distribution:**
    *   Update the "Accept Suggestion" and "Manual Add" flows.
    *   If the target goal has subgoals, show a distribution sheet: "How should we split this $[amount]?"
    *   Provide a "Quick Fill" option to apply funds to the first incomplete subgoal.

## Verification & Testing
-   **Database:**
    *   Insert a subgoal via SQL and verify the parent goal's `target_amount` updates automatically.
    *   Delete a subgoal and verify the parent totals decrease.
-   **Backend:**
    *   Invoke `generate-suggestions` with a composite goal and verify Gemini's reasoning mentions a subgoal.
-   **Frontend:**
    *   **Unit Tests:** Verify `Goal` model can correctly parse a response with a nested `sub_goals` list.
    *   **Widget Tests:** Verify the `GoalDetailScreen` correctly displays multiple subgoals.
    *   **Manual Test:** Add a subgoal in the app and confirm the parent progress bar updates on the dashboard.

## Migration & Rollback
-   **Migration:** Run `supabase db reset` locally to apply the new schema.
-   **Rollback:** Delete the migration file and the `sub_goals` table. Note: Parent goals will retain their last calculated totals until manually updated or another trigger fires.
