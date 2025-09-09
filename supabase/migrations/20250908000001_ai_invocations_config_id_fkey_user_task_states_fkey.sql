-- Add ON DELETE SET NULL constraint to ai_invocations.config_id reference

-- First, drop the existing foreign key constraint
alter table ai_invocations 
  drop constraint ai_invocations_config_id_fkey;

-- Allow config_id to be NULL (required for ON DELETE SET NULL to work)
alter table ai_invocations 
  alter column config_id drop not null;

-- Re-add the foreign key constraint with ON DELETE SET NULL
alter table ai_invocations 
  add constraint ai_invocations_config_id_fkey 
  foreign key (config_id) 
  references ai_prompt_config(id) 
  on delete set null;

-- Add foreign key constraint for user_task_states.task_id with ON DELETE CASCADE

-- Add the foreign key constraint with ON DELETE CASCADE
alter table user_task_states 
  add constraint user_task_states_task_id_fkey 
  foreign key (task_id) 
  references tasks(id) 
  on delete cascade;
