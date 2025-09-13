-- Create function to atomically increment processing budget with a cap
create or replace function increment_processing_budget(
  p_user_id uuid,
  p_amount bigint,
  p_max_budget bigint
) returns bigint
language plpgsql
security definer
as $$
declare
  new_remaining bigint;
begin
  -- Atomically increment and return the new remaining amount, capped at max_budget
  update processing_budgets
  set remaining_nano_usd = least(remaining_nano_usd + p_amount, p_max_budget),
      updated_at = timezone('utc', now())
  where user_id = p_user_id
  returning remaining_nano_usd into new_remaining;
  
  -- If no row was found, insert a new one with the amount (capped at max_budget)
  if not found then
    insert into processing_budgets (user_id, remaining_nano_usd, updated_at)
    values (p_user_id, least(p_amount, p_max_budget), timezone('utc', now()))
    returning remaining_nano_usd into new_remaining;
  end if;
  
  return new_remaining;
end;
$$;

-- Grant execute permission to service role
grant execute on function increment_processing_budget(uuid, bigint, bigint) to service_role;
