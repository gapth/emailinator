create table if not exists ai_prompt_config (
  id uuid primary key default gen_random_uuid(),
  is_active boolean not null default false,
  model text not null,
  prompt text not null,
  temperature real,
  top_p real,
  seed int,
  input_cost_nano_per_token bigint not null,
  output_cost_nano_per_token bigint not null,
  cost_currency text not null default 'USD',
  created_at timestamptz not null default now()
);

alter table ai_prompt_config enable row level security;
create policy "Service role only" on ai_prompt_config for all
  using (auth.role() = 'service_role');

create table if not exists ai_invocations (
  id uuid primary key default gen_random_uuid(),
  config_id uuid not null references ai_prompt_config(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_tokens int not null,
  response_tokens int not null,
  input_cost_nano bigint not null,
  output_cost_nano bigint not null,
  total_cost_nano bigint generated always as (input_cost_nano + output_cost_nano) stored,
  latency_ms int,
  created_at timestamptz not null default now()
);

alter table ai_invocations enable row level security;
create policy "Service role only" on ai_invocations for all
  using (auth.role() = 'service_role');
