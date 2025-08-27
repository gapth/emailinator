-- Table for storing forwarding verification links
create table if not exists forwarding_verifications (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  alias text not null,
  from_email text,
  subject text,
  verification_link text not null,
  created_at timestamptz not null default now(),
  clicked_at timestamptz
);

create index if not exists idx_forwarding_verifications_user on forwarding_verifications(user_id);

alter table forwarding_verifications enable row level security;

create policy "forwarding_verifications select" on forwarding_verifications
  for select using (auth.uid() = user_id);

create policy "forwarding_verifications update" on forwarding_verifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
