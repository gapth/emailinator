-- Migrate ai_prompt_config, ai_invocations, and email_aliases primary keys to BIGSERIAL
-- This migration preserves existing data by introducing new bigint keys, backfilling,
-- and then swapping columns and constraints. It also remaps ai_invocations.config_id
-- to reference the new bigint key on ai_prompt_config with ON DELETE SET NULL.

begin;

-- 1) ai_prompt_config: add bigint PK column and backfill
alter table ai_prompt_config add column if not exists id_big bigserial;
update ai_prompt_config set id_big = default where id_big is null;
alter table ai_prompt_config alter column id_big set not null;

-- 2) ai_invocations: add bigint PK column and backfill
alter table ai_invocations add column if not exists id_big bigserial;
update ai_invocations set id_big = default where id_big is null;
alter table ai_invocations alter column id_big set not null;

-- 3) ai_invocations: add bigint FK column to map to new ai_prompt_config.id
alter table ai_invocations add column if not exists config_id_big bigint;

-- Backfill the bigint FK by joining on existing UUID relationship
update ai_invocations i
set config_id_big = apc.id_big
from ai_prompt_config apc
where i.config_id is not null and i.config_id = apc.id;

-- Drop old FK constraint on UUID column (will recreate against bigint)
alter table ai_invocations drop constraint if exists ai_invocations_config_id_fkey;

-- 4) Swap ai_prompt_config UUID PK -> bigint PK
alter table ai_prompt_config drop constraint if exists ai_prompt_config_pkey;
alter table ai_prompt_config rename column id to id_uuid;
alter table ai_prompt_config rename column id_big to id;
alter table ai_prompt_config add constraint ai_prompt_config_pkey primary key (id);
alter table ai_prompt_config drop column id_uuid;

-- 5) Swap ai_invocations UUID PK -> bigint PK
alter table ai_invocations drop constraint if exists ai_invocations_pkey;
alter table ai_invocations rename column id to id_uuid;
alter table ai_invocations rename column id_big to id;
alter table ai_invocations add constraint ai_invocations_pkey primary key (id);
alter table ai_invocations drop column id_uuid;

-- 6) Swap ai_invocations.config_id (UUID) -> bigint and recreate FK
alter table ai_invocations drop column config_id;
alter table ai_invocations rename column config_id_big to config_id;
alter table ai_invocations
  add constraint ai_invocations_config_id_fkey
  foreign key (config_id)
  references ai_prompt_config(id)
  on delete set null;

-- 7) email_aliases: add bigint PK column, backfill, and swap
alter table email_aliases add column if not exists id_big bigserial;
update email_aliases set id_big = default where id_big is null;
alter table email_aliases alter column id_big set not null;

alter table email_aliases drop constraint if exists email_aliases_pkey;
alter table email_aliases rename column id to id_uuid;
alter table email_aliases rename column id_big to id;
alter table email_aliases add constraint email_aliases_pkey primary key (id);
alter table email_aliases drop column id_uuid;

commit;

