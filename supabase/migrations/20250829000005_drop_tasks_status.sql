drop view if exists user_tasks;

create or replace view user_tasks with (security_invoker = on) as
select
  t.id,
  t.user_id,
  t.email_id,
  t.title,
  t.description,
  t.due_date,
  t.consequence_if_ignore,
  t.parent_action,
  t.parent_requirement_level,
  t.student_action,
  t.student_requirement_level,
  t.created_at,
  t.updated_at,
  uts.state,
  uts.completed_at,
  uts.dismissed_at,
  uts.snoozed_until
from
  tasks t
left join
  user_task_states uts on t.id = uts.task_id and t.user_id = uts.user_id
where
  t.user_id = auth.uid();


alter table tasks drop column if exists status;
