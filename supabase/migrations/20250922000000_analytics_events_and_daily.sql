-- Analytics events + daily metrics
-- - Raw events (partitioned by day, 6mo retention handled externally)
-- - Daily rollups per (user_id, day, platform)
-- - Validation trigger for ingest_type='email' -> public.raw_emails(id)
--
-- Canonical event_type values (free-text, validated by convention):
--   App usage:
--     - app_entered
--   Setup funnel (stage reached):
--     - setup_viewed
--     - setup_started
--     - setup_email_connected
--     - setup_inbound_verified
--     - setup_first_email_ingested
--     - setup_ai_extraction_ok
--     - setup_first_task_created
--     - setup_completed
--   Setup diagnostics (attempts/errors):
--     - setup_stage_attempt  -- include setup_stage, success, error_code in columns/metadata
--   Email processing (ingest_type may be 'email'|'share'|'chat'):
--     - email_received
--     - email_processed_success
--     - email_processed_failed
--   Tasks:
--     - task_created
--     - task_action_completed
--     - task_action_dismissed
--     - task_action_snoozed
--     - task_action_reopened
--     - task_action_unsnoozed

begin;

-- Schema
create schema if not exists analytics;

-- Enumerations via CHECKs for agility
create table if not exists analytics.events (
  id bigserial,
  user_id uuid not null,
  platform text not null check (platform in ('ios','android','web','server')),
  source text not null check (source in ('app','edge_function','job')),

  occurred_at timestamptz not null,
  -- Use a plain column for partitioning; generated column rejected as not immutable.
  -- We populate this via a BEFORE trigger to ensure UTC day bucketing.
  occurred_date date not null,

  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,

  -- Option A: client/edge generated UUID for idempotency (uniqueness enforced via partition-safe index below)
  idempotency_key uuid,

  -- Generalized ingest linkage (email/share/chat)
  ingest_type text null check (ingest_type in ('email','share','chat')),
  ingest_id uuid null,

  -- Task linkage
  task_id uuid null,

  -- Setup/funnel details
  setup_stage text null,
  success boolean null,
  error_code text null,

  -- Dimensions
  app_version text null,
  signup_date date null,

  created_at timestamptz not null default now(),

  constraint events_pk primary key (occurred_date, id)
) partition by range (occurred_date);

-- Default partition to avoid insert failures if monthly partitions are absent
create table if not exists analytics.events_default
  partition of analytics.events default;

-- Helpful indexes for common access patterns
create index if not exists events_occurred_date_idx on analytics.events using btree (occurred_date);
create index if not exists events_user_id_occurred_at_idx on analytics.events using btree (user_id, occurred_at);
create index if not exists events_event_type_date_idx on analytics.events using btree (event_type, occurred_date);
create index if not exists events_platform_date_idx on analytics.events using btree (platform, occurred_date);
create index if not exists events_metadata_gin_idx on analytics.events using gin (metadata);

-- Idempotency key uniqueness must include partition key
create unique index if not exists events_idempotency_unique
  on analytics.events (occurred_date, idempotency_key)
  where idempotency_key is not null;

-- Email-event uniqueness per user for specific types (ingest may fan out to multiple users)
create unique index if not exists events_unique_email_per_user
  on analytics.events (occurred_date, user_id, event_type, ingest_type, ingest_id)
  where ingest_id is not null
    and ingest_type = 'email'
    and event_type in ('email_received','email_processed_success','email_processed_failed');

-- Safety-net uniqueness for task actions (alongside idempotency_key)
create unique index if not exists events_unique_task_action
  on analytics.events (occurred_date, user_id, task_id, event_type, occurred_at)
  where task_id is not null and event_type like 'task_action_%';

-- Validation trigger for ingest_type/id consistency and email FK existence
create or replace function analytics.validate_event_ingest()
returns trigger
language plpgsql
as $$
declare
  v_ingest_type text;
  v_ingest_id uuid;
begin
  v_ingest_type := coalesce(new.ingest_type, old.ingest_type);
  v_ingest_id := coalesce(new.ingest_id, old.ingest_id);

  -- Ensure UTC day bucketing independent of session TimeZone.
  if tg_op = 'INSERT' or (new.occurred_at is distinct from old.occurred_at) then
    new.occurred_date := (new.occurred_at at time zone 'UTC')::date;
  end if;

  -- Enforce paired nullability
  if (new.ingest_type is null) <> (new.ingest_id is null) then
    raise exception 'ingest_type and ingest_id must both be null or both be non-null';
  end if;

  -- Validate email linkage when present
  if new.ingest_type = 'email' and new.ingest_id is not null then
    if not exists (select 1 from public.raw_emails e where e.id = new.ingest_id) then
      raise exception 'Invalid ingest_id: % not found in public.raw_emails', new.ingest_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_event_ingest on analytics.events;
create trigger trg_validate_event_ingest
before insert or update on analytics.events
for each row execute function analytics.validate_event_ingest();

-- Daily summary (no "all" platform row; caller can aggregate across platforms)
create table if not exists analytics.user_daily_metrics (
  user_id uuid not null,
  day date not null,
  platform text not null check (platform in ('ios','android','web','server')),

  last_app_version text null,
  signup_date date null,

  app_entries_count int not null default 0,

  emails_received_count int not null default 0,
  emails_processed_count int not null default 0,
  emails_failed_count int not null default 0,

  tasks_acted_on_count int not null default 0,
  action_completed_count int not null default 0,
  action_dismissed_count int not null default 0,
  action_snoozed_count int not null default 0,
  action_reopened_count int not null default 0,
  action_unsnoozed_count int not null default 0,

  latest_setup_stage text null,
  setup_attempt_counts jsonb not null default '{}'::jsonb,

  first_event_at timestamptz null,
  last_event_at timestamptz null,

  updated_at timestamptz not null default now(),

  constraint user_daily_metrics_pk primary key (user_id, day, platform)
);

create index if not exists user_daily_metrics_day_idx on analytics.user_daily_metrics (day);

-- Optional helper: create monthly partitions for events
create or replace function analytics.ensure_monthly_partition(p_month date)
returns void
language plpgsql
as $$
declare
  v_start date := date_trunc('month', p_month)::date;
  v_end date := (v_start + interval '1 month')::date;
  v_partition_name text := format('events_%s', to_char(v_start, 'YYYYMM'));
  v_sql text;
begin
  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'analytics' and c.relname = v_partition_name
  ) then
    v_sql := format('create table analytics.%I partition of analytics.events for values from (%L) to (%L);', v_partition_name, v_start, v_end);
    execute v_sql;
  end if;
end;
$$;

-- Aggregation: recompute daily metrics for a date range (UTC days)
create or replace function analytics.recompute_user_daily_metrics(p_start_date date, p_end_date date)
returns void
language plpgsql
as $$
begin
  -- Normalize bounds
  if p_start_date is null or p_end_date is null then
    raise exception 'start and end dates are required';
  end if;
  if p_end_date < p_start_date then
    raise exception 'end date % precedes start date %', p_end_date, p_start_date;
  end if;

  -- Delete existing rows in range to allow idempotent recompute
  delete from analytics.user_daily_metrics m
   where m.day between p_start_date and p_end_date;

  with base as (
    select
      e.user_id,
      e.platform,
      e.occurred_date as day,
      e.event_type,
      e.task_id,
      e.ingest_type,
      e.ingest_id,
      e.setup_stage,
      e.app_version,
      e.signup_date,
      e.occurred_at
    from analytics.events e
    where e.occurred_date between p_start_date and p_end_date
  ),
  version_last as (
    select distinct on (user_id, day, platform)
      user_id, day, platform,
      app_version,
      occurred_at
    from base
    where app_version is not null
    order by user_id, day, platform, occurred_at desc
  ),
  usage as (
    select user_id, day, platform,
           count(*) filter (where event_type = 'app_entered') as app_entries_count
    from base
    group by user_id, day, platform
  ),
  emails as (
    select user_id, day, platform,
      count(distinct ingest_id) filter (where event_type = 'email_received' and ingest_type = 'email' and ingest_id is not null) as emails_received_count,
      count(distinct ingest_id) filter (where event_type = 'email_processed_success' and ingest_type = 'email' and ingest_id is not null) as emails_processed_count,
      count(distinct ingest_id) filter (where event_type = 'email_processed_failed' and ingest_type = 'email' and ingest_id is not null) as emails_failed_count
    from base
    group by user_id, day, platform
  ),
  tasks as (
    select user_id, day, platform,
      count(distinct task_id) filter (where event_type like 'task_action_%' and task_id is not null) as tasks_acted_on_count,
      count(*) filter (where event_type = 'task_action_completed') as action_completed_count,
      count(*) filter (where event_type = 'task_action_dismissed') as action_dismissed_count,
      count(*) filter (where event_type = 'task_action_snoozed') as action_snoozed_count,
      count(*) filter (where event_type = 'task_action_reopened') as action_reopened_count,
      count(*) filter (where event_type = 'task_action_unsnoozed') as action_unsnoozed_count
    from base
    group by user_id, day, platform
  ),
  funnel as (
    -- latest_setup_stage by a simple ordering of known stages; stages not seen remain null
    select user_id, day, platform,
      (
        select s.stage from (
          values
            (1,'setup_viewed'),
            (2,'setup_started'),
            (3,'setup_email_connected'),
            (4,'setup_inbound_verified'),
            (5,'setup_first_email_ingested'),
            (6,'setup_ai_extraction_ok'),
            (7,'setup_first_task_created'),
            (8,'setup_completed')
        ) as s(ord, stage)
        where exists (
          select 1 from base b2
          where b2.user_id = b.user_id
            and b2.day = b.day
            and b2.platform = b.platform
            and b2.event_type = s.stage
        )
        order by ord desc
        limit 1
      ) as latest_setup_stage,
      (
        select coalesce(jsonb_object_agg(t.setup_stage, t.cnt), '{}'::jsonb)
        from (
          select setup_stage, count(*) as cnt
          from base b3
          where b3.user_id = b.user_id
            and b3.day = b.day
            and b3.platform = b.platform
            and b3.event_type = 'setup_stage_attempt'
          group by setup_stage
        ) t
      ) as setup_attempt_counts
    from base b
    group by user_id, day, platform
  ),
  windowing as (
    select user_id, day, platform,
      min(occurred_at) as first_event_at,
      max(occurred_at) as last_event_at,
      min(signup_date) as signup_date
    from base
    group by user_id, day, platform
  ),
  merged as (
    select
      w.user_id,
      w.day,
      w.platform,
      vl.app_version as last_app_version,
      w.signup_date,
      coalesce(u.app_entries_count, 0) as app_entries_count,
      coalesce(em.emails_received_count, 0) as emails_received_count,
      coalesce(em.emails_processed_count, 0) as emails_processed_count,
      coalesce(em.emails_failed_count, 0) as emails_failed_count,
      coalesce(t.tasks_acted_on_count, 0) as tasks_acted_on_count,
      coalesce(t.action_completed_count, 0) as action_completed_count,
      coalesce(t.action_dismissed_count, 0) as action_dismissed_count,
      coalesce(t.action_snoozed_count, 0) as action_snoozed_count,
      coalesce(t.action_reopened_count, 0) as action_reopened_count,
      coalesce(t.action_unsnoozed_count, 0) as action_unsnoozed_count,
      f.latest_setup_stage,
      coalesce(f.setup_attempt_counts, '{}'::jsonb) as setup_attempt_counts,
      w.first_event_at,
      w.last_event_at
    from windowing w
    left join version_last vl on (vl.user_id = w.user_id and vl.day = w.day and vl.platform = w.platform)
    left join usage u on (u.user_id = w.user_id and u.day = w.day and u.platform = w.platform)
    left join emails em on (em.user_id = w.user_id and em.day = w.day and em.platform = w.platform)
    left join tasks t on (t.user_id = w.user_id and t.day = w.day and t.platform = w.platform)
    left join funnel f on (f.user_id = w.user_id and f.day = w.day and f.platform = w.platform)
  )
  insert into analytics.user_daily_metrics as m (
    user_id, day, platform,
    last_app_version, signup_date,
    app_entries_count,
    emails_received_count, emails_processed_count, emails_failed_count,
    tasks_acted_on_count,
    action_completed_count, action_dismissed_count, action_snoozed_count, action_reopened_count, action_unsnoozed_count,
    latest_setup_stage, setup_attempt_counts,
    first_event_at, last_event_at,
    updated_at
  )
  select
    user_id, day, platform,
    last_app_version, signup_date,
    app_entries_count,
    emails_received_count, emails_processed_count, emails_failed_count,
    tasks_acted_on_count,
    action_completed_count, action_dismissed_count, action_snoozed_count, action_reopened_count, action_unsnoozed_count,
    latest_setup_stage, setup_attempt_counts,
    first_event_at, last_event_at,
    now()
  from merged
  on conflict (user_id, day, platform) do update set
    last_app_version = excluded.last_app_version,
    signup_date = excluded.signup_date,
    app_entries_count = excluded.app_entries_count,
    emails_received_count = excluded.emails_received_count,
    emails_processed_count = excluded.emails_processed_count,
    emails_failed_count = excluded.emails_failed_count,
    tasks_acted_on_count = excluded.tasks_acted_on_count,
    action_completed_count = excluded.action_completed_count,
    action_dismissed_count = excluded.action_dismissed_count,
    action_snoozed_count = excluded.action_snoozed_count,
    action_reopened_count = excluded.action_reopened_count,
    action_unsnoozed_count = excluded.action_unsnoozed_count,
    latest_setup_stage = excluded.latest_setup_stage,
    setup_attempt_counts = excluded.setup_attempt_counts,
    first_event_at = excluded.first_event_at,
    last_event_at = excluded.last_event_at,
    updated_at = now();
end;
$$;

-- RLS: service role only. Enable RLS; do not create user/anon policies.
alter table analytics.events enable row level security;
alter table analytics.user_daily_metrics enable row level security;

--
-- App-facing RPC to log a single analytics event
-- - SECURITY DEFINER: bypasses RLS but pins user_id to auth.uid()
-- - Grants EXECUTE to role `authenticated`
--
create or replace function public.log_analytics_event(
  _platform text,
  _event_type text,
  _metadata jsonb default '{}'::jsonb,
  _idempotency_key uuid default null,
  _ingest_type text default null,
  _ingest_id uuid default null,
  _task_id uuid default null,
  _setup_stage text default null,
  _occurred_at timestamptz default null,
  _app_version text default null
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_id bigint;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  -- Validate allowed values for platform; source is fixed to 'app' for this RPC
  if _platform not in ('ios','android','web','server') then
    raise exception 'invalid platform: %', _platform;
  end if;

  -- Enforce ingest_type/id pairing
  if (_ingest_type is null) <> (_ingest_id is null) then
    raise exception 'ingest_type and ingest_id must both be null or both be non-null';
  end if;

  -- Optional: restrict known ingest types
  if _ingest_type is not null and _ingest_type not in ('email','share','chat') then
    raise exception 'invalid ingest_type: %', _ingest_type;
  end if;

  -- Default timestamp to now (UTC) if not provided
  if _occurred_at is null then
    _occurred_at := v_now;
  end if;

  begin
    insert into analytics.events (
      user_id, platform, source,
      occurred_at, event_type, metadata,
      idempotency_key,
      ingest_type, ingest_id,
      task_id,
      setup_stage,
      app_version,
      signup_date
    ) values (
      v_user_id, _platform, 'app',
      _occurred_at, _event_type, coalesce(_metadata, '{}'::jsonb),
      _idempotency_key,
      _ingest_type, _ingest_id,
      _task_id,
      _setup_stage,
      _app_version,
      null -- caller does not set signup_date; can be backfilled elsewhere
    )
    returning id into v_id;
  exception when unique_violation then
    -- If this is a retry with same idempotency key or other unique index, swallow
    -- and fetch the existing row id by the most reliable key available.
    if _idempotency_key is not null then
      select e.id into v_id from analytics.events e where e.idempotency_key = _idempotency_key;
      if v_id is not null then
        return v_id;
      end if;
    end if;
    -- Fallback for email uniqueness per user
    if _ingest_id is not null and _ingest_type = 'email' and _event_type in ('email_received','email_processed_success','email_processed_failed') then
      select e.id into v_id from analytics.events e
      where e.user_id = v_user_id and e.event_type = _event_type and e.ingest_type = _ingest_type and e.ingest_id = _ingest_id
      order by e.id desc limit 1;
      if v_id is not null then
        return v_id;
      end if;
    end if;
    -- Fallback for task action uniqueness
    if _task_id is not null and _event_type like 'task_action_%' then
      select e.id into v_id from analytics.events e
      where e.user_id = v_user_id and e.task_id = _task_id and e.event_type = _event_type and e.occurred_at = _occurred_at
      order by e.id desc limit 1;
      if v_id is not null then
        return v_id;
      end if;
    end if;
    -- Re-raise if not identifiable
    raise;
  end;

  return v_id;
end;
$$;

revoke all on function public.log_analytics_event(text, text, jsonb, uuid, text, uuid, uuid, text, timestamptz, text) from public;
grant execute on function public.log_analytics_event(text, text, jsonb, uuid, text, uuid, uuid, text, timestamptz, text) to authenticated;
grant execute on function public.log_analytics_event(text, text, jsonb, uuid, text, uuid, uuid, text, timestamptz, text) to service_role;

commit;
