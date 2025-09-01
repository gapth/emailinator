-- Add overdue_grace_days preference to control overdue task cutoff
-- overdue_grace_days: number of days after which OPEN tasks are considered overdue (default 14)

alter table preferences
  add column overdue_grace_days int default 14;
