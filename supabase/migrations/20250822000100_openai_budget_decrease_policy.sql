-- Allow users to decrease their own remaining budget but not increase it
create or replace function public.openai_budget_can_decrease(new_remaining bigint)
returns boolean
language sql
security definer
set search_path = public
as $$
  select new_remaining <= remaining_nano_usd
  from openai_budget
  where user_id = auth.uid();
$$;

grant execute on function public.openai_budget_can_decrease(bigint) to authenticated, service_role;

create policy "Users can decrease own budget" on openai_budget
  for update using (auth.uid() = user_id)
  with check (openai_budget_can_decrease(remaining_nano_usd));
