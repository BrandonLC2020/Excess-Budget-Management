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
