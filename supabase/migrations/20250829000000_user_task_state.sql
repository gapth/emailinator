create type task_state as enum ('OPEN','COMPLETED','DISMISSED','SNOOZED');

create table if not exists user_task_state (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null, -- your existing task id
  state task_state not null default 'OPEN',
  completed_at timestamptz,
  dismissed_at timestamptz,
  snoozed_until date,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, task_id)
);

create index on user_task_state (user_id, state);

alter table user_task_state enable row level security;


create policy "Allow users to access their own task state"
on user_task_state for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


create or replace view user_tasks with (security_invoker = on) as
select
  t.*,
  uts.state,
  uts.completed_at,
  uts.dismissed_at,
  uts.snoozed_until
from
  tasks t
left join
  user_task_state uts on t.id = uts.task_id and t.user_id = uts.user_id
where
  t.user_id = auth.uid();
