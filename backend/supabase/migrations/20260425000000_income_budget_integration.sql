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
