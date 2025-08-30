-- Update user_tasks view to default state to 'OPEN' when no user_task_states record exists
create or replace view user_tasks with (security_invoker = on) as
select
  t.*,
  coalesce(uts.state, 'OPEN'::task_state) as state,
  uts.completed_at,
  uts.dismissed_at,
  uts.snoozed_until
from
  tasks t
left join
  user_task_states uts on t.id = uts.task_id and t.user_id = uts.user_id
where
  t.user_id = auth.uid();
