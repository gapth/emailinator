-- Update upcoming preferences: add upcoming_days and remove deprecated date offset preferences
-- upcoming_days: number of days from today to show upcoming tasks (default 30)
-- upcoming_days=1 means show tasks due today only, upcoming_days=2 means today and tomorrow, etc.

alter table preferences
  add column upcoming_days int default 30,
  drop column if exists date_start_offset_days,
  drop column if exists date_end_offset_days;
