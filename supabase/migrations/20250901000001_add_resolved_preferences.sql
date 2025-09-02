-- Combined migration for resolved preferences
-- Add preferences for resolved section and remove deprecated show_history

-- Add resolved preferences
alter table preferences
  add column resolved_show_completed boolean default true,
  add column resolved_days int default 60,
  add column resolved_show_dismissed boolean default false;

-- Remove deprecated show_history preference
alter table preferences
  drop column if exists show_history;
