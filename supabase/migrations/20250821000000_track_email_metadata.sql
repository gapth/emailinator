-- Add fields for tracking email processing and API usage
alter table raw_emails rename column received_at to processed_at;
alter index if exists idx_raw_emails_received_at rename to idx_raw_emails_processed_at;

alter table raw_emails
  add column sent_at timestamptz,
  add column message_id text,
  add column openai_input_cost_nano_usd bigint,
  add column openai_output_cost_nano_usd bigint,
  add column tasks_before integer,
  add column tasks_after integer,
  add column status text not null default 'UNPROCESSED'
    check (status in ('UNPROCESSED','UPDATED_TASKS'));
