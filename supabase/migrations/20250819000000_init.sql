-- Extensions
create extension if not exists pgcrypto;

-- RAW EMAILS (we keep them)
create table if not exists raw_emails (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  from_email text,
  to_email text,
  subject text,
  text_body text,
  html_body text,
  received_at timestamptz not null default now(),
  provider_meta jsonb
);

-- TASKS (no dedupe/embedding fields; schema mirrors your JSON)
create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email_id uuid references raw_emails(id) on delete set null,

  -- JSON schema fields:
  title text not null,                             -- required
  description text,                                -- concise but complete summary
  due_date date,                                   -- YYYY-MM-DD if explicitly stated
  consequence_if_ignore text,                      -- natural-language consequence

  parent_action text check (
    parent_action in (
      'NONE','SUBMIT','SIGN','PAY','PURCHASE','ATTEND','TRANSPORT','VOLUNTEER','OTHER'
    )
  ),
  parent_requirement_level text check (
    parent_requirement_level in (
      'NONE','OPTIONAL','VOLUNTEER','MANDATORY'
    )
  ),

  student_action text check (
    student_action in (
      'NONE','SUBMIT','ATTEND','SETUP','BRING','PREPARE','WEAR','COLLECT','OTHER'
    )
  ),
  student_requirement_level text check (
    student_requirement_level in (
      'NONE','OPTIONAL','VOLUNTEER','MANDATORY'
    )
  ),

  status text check (
    status in (
      'PENDING','DONE','DISMISSED'
    )
  ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep things snappy for typical queries
create index if not exists idx_tasks_user on tasks(user_id);
create index if not exists idx_tasks_user_due on tasks(user_id, due_date);
create index if not exists idx_raw_emails_user on raw_emails(user_id);
create index if not exists idx_raw_emails_received_at on raw_emails(received_at);

-- UPDATE trigger for updated_at
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_tasks_updated_at on tasks;
create trigger trg_tasks_updated_at
before update on tasks
for each row execute procedure set_updated_at();

-- Preferences (kept minimal; adjust as needed)
create table if not exists preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  requirement_level text default 'MANDATORY', -- e.g., MANDATORY/OPTIONAL/ALL if you expand later
  muted_keywords text[] default '{}'
);

-- Row-Level Security
alter table raw_emails enable row level security;
alter table tasks enable row level security;
alter table preferences enable row level security;

-- Owner can read/write their own rows
create policy "raw_emails owner read"
  on raw_emails for select
  using (auth.uid() = user_id);

create policy "raw_emails owner insert"
  on raw_emails for insert
  with check (auth.uid() = user_id);

create policy "tasks owner select"
  on tasks for select
  using (auth.uid() = user_id);

create policy "tasks owner insert"
  on tasks for insert
  with check (auth.uid() = user_id);

create policy "tasks owner update"
  on tasks for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "tasks owner delete"
  on tasks for delete
  using (auth.uid() = user_id);

create policy "preferences owner all"
  on preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
