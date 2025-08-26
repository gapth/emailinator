-- Table for storing per-user email aliases for forwarding
create table if not exists email_aliases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  alias text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Ensure only one active alias per user
create unique index if not exists idx_email_aliases_unique_active
  on email_aliases(user_id) where active;

alter table email_aliases enable row level security;

create policy "email_aliases owner select"
  on email_aliases for select
  using (auth.uid() = user_id);

create policy "email_aliases owner insert"
  on email_aliases for insert
  with check (auth.uid() = user_id);

create policy "email_aliases owner update"
  on email_aliases for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "email_aliases owner delete"
  on email_aliases for delete
  using (auth.uid() = user_id);
