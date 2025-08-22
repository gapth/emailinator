-- Update preferences schema for Supabase tasks UI
alter table preferences
  add column parent_requirement_levels text[] default '{}';

update preferences set parent_requirement_levels = array[requirement_level]
  where requirement_level is not null;

alter table preferences
  drop column requirement_level;

alter table preferences
  drop column muted_keywords;

alter table preferences
  add column include_no_due_date boolean default true;
