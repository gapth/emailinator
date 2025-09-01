-- Add date offset preferences to control default date range
-- date_start_offset_days: days to subtract from current date for start of range (negative number)
-- date_end_offset_days: days to add to current date for end of range (positive number)

alter table preferences
  add column date_start_offset_days int default -7,
  add column date_end_offset_days int default 30;
