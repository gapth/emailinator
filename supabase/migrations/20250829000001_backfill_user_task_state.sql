insert into user_task_state (user_id, task_id, state, completed_at, dismissed_at, created_at, updated_at)
select
  t.user_id,
  t.id,
  case t.status
    when 'PENDING' then 'OPEN'
    when 'DONE' then 'COMPLETED'
    when 'DISMISSED' then 'DISMISSED'
  end::task_state,
  case when t.status = 'DONE' then t.updated_at else null end,
  case when t.status = 'DISMISSED' then t.updated_at else null end,
  t.created_at,
  t.updated_at
from
  tasks t
on conflict (user_id, task_id) do nothing;
