-- Link AI invocations to the source email and drop duplicated cost columns from raw_emails

-- 1) Add email_id to ai_invocations (nullable, since some invocations may not be tied to an email)
alter table ai_invocations
  add column if not exists email_id uuid references raw_emails(id) on delete set null;

create index if not exists idx_ai_invocations_email_id on ai_invocations(email_id);

-- 2) Drop duplicated cost columns from raw_emails now that costs are tracked in ai_invocations
alter table raw_emails drop column if exists openai_input_cost_nano_usd;
alter table raw_emails drop column if exists openai_output_cost_nano_usd;
