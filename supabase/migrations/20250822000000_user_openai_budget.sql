create table if not exists openai_budget (
  user_id uuid primary key references auth.users on delete cascade,
  remaining_nano_usd bigint not null default 0,
  inserted_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table openai_budget enable row level security;

create policy "Users can read own budget" on openai_budget
  for select using (auth.uid() = user_id);

create policy "Service role manage budgets" on openai_budget
  for all using (auth.role() = 'service_role');
