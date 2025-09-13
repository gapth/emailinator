-- Update user_tasks view to include sent_at from raw_emails
drop view if exists user_tasks;

create or replace view user_tasks with (security_invoker = on) as
select
  t.id,
  t.user_id,
  t.email_id,
  t.title,
  t.description,
  t.due_date,
  t.parent_action,
  t.parent_requirement_level,
  t.student_action,
  t.student_requirement_level,
  t.created_at,
  t.updated_at,
  coalesce(uts.state, 'OPEN'::task_state) as state,
  uts.completed_at,
  uts.dismissed_at,
  uts.snoozed_until,
  re.sent_at
from
  tasks t
left join
  user_task_states uts on t.id = uts.task_id and t.user_id = uts.user_id
left join
  raw_emails re on t.email_id = re.id
where
  t.user_id = auth.uid();
