-- Add show_history preference to control display of completed/dismissed tasks
alter table preferences
  add column show_history boolean default false;
