-- Create table to track canonical sources seen in forwarded mail
create table if not exists public.source_observations (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  registrable_domain text not null,             -- e.g., parentsquare.com
  list_id text,                                 -- raw List-ID header if present
  dkim_d text,                                  -- d= value from DKIM-Signature or Authentication-Results
  sender_domain text,                           -- domain from From/Return-Path
  unsubscribe_domain text,                      -- host from List-Unsubscribe URL
  platform_hint text,                           -- e.g., 'parentsquare' (lowercased token)
  msg_first_seen timestamptz not null default now(),
  msg_last_seen timestamptz not null default now(),
  msg_count int not null default 1
);

-- Ensure one row per user + registrable_domain
create unique index if not exists source_observations_user_domain_uniq
  on public.source_observations (user_id, registrable_domain);

comment on table public.source_observations is 'Canonical source observations extracted from inbound emails per user.';
comment on column public.source_observations.registrable_domain is 'eTLD+1 (registrable) domain used for grouping (e.g., parentsquare.com)';
comment on column public.source_observations.platform_hint is 'Heuristic platform name derived from observed domains (e.g., parentsquare)';

