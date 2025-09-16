-- Rename ai_prompt_config to ai_prompt_configs for naming consistency
-- Foreign key references will follow automatically in PostgreSQL

begin;

alter table if exists ai_prompt_config rename to ai_prompt_configs;

commit;
