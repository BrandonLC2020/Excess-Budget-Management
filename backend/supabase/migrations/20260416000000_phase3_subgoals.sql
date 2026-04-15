-- Phase 3 - Subgoal Tracking & Aggregation

-- 1. Create public.sub_goals table for categorical goal line items
CREATE TABLE public.sub_goals (
  id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
  goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  target_amount numeric(12, 2) NOT NULL,
  current_amount numeric(12, 2) DEFAULT 0.00 NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Enable RLS for sub_goals
ALTER TABLE public.sub_goals ENABLE ROW LEVEL SECURITY;

-- 3. sub_goals RLS policies
CREATE POLICY "Users can view own subgoals" ON public.sub_goals FOR SELECT USING ( auth.uid() = user_id );
CREATE POLICY "Users can insert own subgoals" ON public.sub_goals FOR INSERT WITH CHECK ( auth.uid() = user_id );
CREATE POLICY "Users can update own subgoals" ON public.sub_goals FOR UPDATE USING ( auth.uid() = user_id );
CREATE POLICY "Users can delete own subgoals" ON public.sub_goals FOR DELETE USING ( auth.uid() = user_id );

-- 4. Create database function to roll up subgoal totals to parent goals
CREATE OR REPLACE FUNCTION public.calculate_parent_goal_totals()
RETURNS TRIGGER AS $$
DECLARE
  target_goal_id uuid;
BEGIN
  -- Determine which goal_id we need to update
  IF TG_OP = 'DELETE' THEN
    target_goal_id := OLD.goal_id;
  ELSE
    target_goal_id := NEW.goal_id;
  END IF;

  -- Update the parent goal's amounts based on all its subgoals
  UPDATE public.goals
  SET 
    target_amount = (
      SELECT COALESCE(SUM(target_amount), 0) 
      FROM public.sub_goals 
      WHERE goal_id = target_goal_id
    ),
    current_amount = (
      SELECT COALESCE(SUM(current_amount), 0) 
      FROM public.sub_goals 
      WHERE goal_id = target_goal_id
    )
  WHERE id = target_goal_id
    AND EXISTS (SELECT 1 FROM public.sub_goals WHERE goal_id = target_goal_id);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create trigger to run after every change to sub_goals
CREATE TRIGGER trigger_sub_goals_aggregation
AFTER INSERT OR UPDATE OR DELETE ON public.sub_goals
FOR EACH ROW EXECUTE FUNCTION public.calculate_parent_goal_totals();
