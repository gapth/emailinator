-- Remove include_no_due_date column from preferences table
-- This setting is no longer needed as creation date is used as effective due date when due_date is null

alter table preferences
  drop column if exists include_no_due_date;
