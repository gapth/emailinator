-- Add Row Level Security to source_observations table
-- Only allow users to access their own rows

-- Enable Row Level Security
alter table public.source_observations enable row level security;

-- Policy: Users can only access their own source observations
create policy "Users can access their own source observations"
  on public.source_observations
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
