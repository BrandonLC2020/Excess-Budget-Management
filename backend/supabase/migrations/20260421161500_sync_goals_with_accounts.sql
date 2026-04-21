-- 1. Add account_id to goals table
ALTER TABLE public.goals 
ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL;

CREATE INDEX idx_goals_account_id ON public.goals(account_id);

-- 2. Create function to sync goal progress with account balance
CREATE OR REPLACE FUNCTION public.sync_goal_progress_with_account()
RETURNS TRIGGER AS $$
BEGIN
    -- If an account balance changes, update all linked goals
    IF (TG_TABLE_NAME = 'accounts') THEN
        UPDATE public.goals
        SET current_amount = NEW.balance
        WHERE account_id = NEW.id;
        RETURN NEW;
    END IF;

    -- If a goal is created or updated with an account_id, sync its current_amount
    IF (TG_TABLE_NAME = 'goals') THEN
        IF NEW.account_id IS NOT NULL THEN
            SELECT balance INTO NEW.current_amount
            FROM public.accounts
            WHERE id = NEW.account_id;
        END IF;
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create triggers
-- On accounts update
DROP TRIGGER IF EXISTS trigger_sync_goals_on_account_update ON public.accounts;
CREATE TRIGGER trigger_sync_goals_on_account_update
AFTER UPDATE OF balance ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.sync_goal_progress_with_account();

-- On goals insert or update
DROP TRIGGER IF EXISTS trigger_sync_goal_on_goal_upsert ON public.goals;
CREATE TRIGGER trigger_sync_goal_on_goal_upsert
BEFORE INSERT OR UPDATE OF account_id ON public.goals
FOR EACH ROW EXECUTE FUNCTION public.sync_goal_progress_with_account();
