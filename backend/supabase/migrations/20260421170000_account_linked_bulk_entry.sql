-- backend/supabase/migrations/20260421170000_account_linked_bulk_entry.sql

-- Add account_id to expenses
ALTER TABLE public.expenses ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL;

-- Add account_id to extra_income
ALTER TABLE public.extra_income ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL;

-- Trigger function for expenses balance
CREATE OR REPLACE FUNCTION public.handle_expense_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle Insert
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
    END IF;
  
  -- Handle Delete
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
    END IF;

  -- Handle Update
  ELSIF (TG_OP = 'UPDATE') THEN
    -- If account changed
    IF (OLD.account_id IS DISTINCT FROM NEW.account_id) THEN
      IF (OLD.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
      END IF;
      IF (NEW.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
      END IF;
    -- If amount changed on the same account
    ELSIF (OLD.amount IS DISTINCT FROM NEW.amount AND NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance + OLD.amount - NEW.amount WHERE id = NEW.account_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function for income balance
CREATE OR REPLACE FUNCTION public.handle_income_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
    END IF;
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
    END IF;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF (OLD.account_id IS DISTINCT FROM NEW.account_id) THEN
      IF (OLD.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
      END IF;
      IF (NEW.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
      END IF;
    ELSIF (OLD.amount IS DISTINCT FROM NEW.amount AND NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance - OLD.amount + NEW.amount WHERE id = NEW.account_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER trigger_expense_balance
AFTER INSERT OR UPDATE OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.handle_expense_account_balance();

CREATE TRIGGER trigger_income_balance
AFTER INSERT OR UPDATE OR DELETE ON public.extra_income
FOR EACH ROW EXECUTE FUNCTION public.handle_income_account_balance();
