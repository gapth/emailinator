-- Create function to atomically decrement processing budget
create or replace function decrement_processing_budget(
  p_user_id uuid,
  p_amount bigint
) returns bigint
language plpgsql
security definer
as $$
declare
  new_remaining bigint;
begin
  -- Atomically decrement and return the new remaining amount
  update processing_budgets
  set remaining_nano_usd = remaining_nano_usd - p_amount,
      updated_at = timezone('utc', now())
  where user_id = p_user_id
  returning remaining_nano_usd into new_remaining;
  
  -- If no row was found, return null
  if not found then
    return null;
  end if;
  
  return new_remaining;
end;
$$;

-- Grant execute permission to service role
grant execute on function decrement_processing_budget(uuid, bigint) to service_role;
