import {
  extractNewTasks,
  addNewTasksAndUpdateEmail,
  chooseEmailText,
  getOpenTasksForDeduplication,
  getUserProcessingBudget,
  decrementProcessingBudget,
} from '../_shared/task-utils.ts';

export interface Deps {
  // deno-lint-ignore no-explicit-any
  supabase: any;
  fetch: typeof fetch;
  openAiApiKey: string;
  serviceRoleKey: string;
}

export function createHandler({
  supabase,
  fetch,
  openAiApiKey,
  serviceRoleKey,
}: Deps) {
  return async function handler(req: Request): Promise<Response> {
    if (req.method !== 'POST')
      return new Response('Method Not Allowed', { status: 405 });

    const auth = req.headers.get('authorization');
    if (auth !== `Bearer ${serviceRoleKey}`)
      return new Response('Unauthorized', { status: 401 });

    const { data: raws, error } = await supabase
      .from('raw_emails')
      .select('*')
      .eq('status', 'UNPROCESSED')
      .order('sent_at', { ascending: true });
    if (error) return new Response(error.message, { status: 500 });

    let processed = 0;
    // deno-lint-ignore no-explicit-any
    for (const raw of raws as any[]) {
      try {
        const user_id = raw.user_id;
        const emailText = chooseEmailText(raw);

        const { budget: remainingBudget, error: budgetError } =
          await getUserProcessingBudget(supabase, user_id);
        if (budgetError || remainingBudget <= 0) continue;

        const { tasks: existingForAi, error: existingError } =
          await getOpenTasksForDeduplication(supabase, user_id);
        if (existingError) continue;

        const {
          tasks,
          promptTokens,
          completionTokens,
          totalCostNano,
          rawContent,
        } = await extractNewTasks(
          supabase,
          fetch,
          openAiApiKey,
          emailText,
          existingForAi,
          user_id,
          raw.id
        );

        const result = await addNewTasksAndUpdateEmail({
          supabase,
          userId: user_id,
          rawEmailId: raw.id,
          newTasks: tasks,
          existingTasksCount: existingForAi.length,
          _promptTokens: promptTokens,
          _completionTokens: completionTokens,
          rawContent,
          logPrefix: 'reprocess-unprocessed',
        });
        if (result.success) {
          processed++;

          // Atomically decrement the remaining budget using database function
          const { error: budgetUpdateError } = await decrementProcessingBudget(
            supabase,
            user_id,
            totalCostNano,
            'reprocess-unprocessed'
          );

          if (budgetUpdateError) {
            console.error(
              `[reprocess-unprocessed] Budget update error for user ${user_id}: ${budgetUpdateError}`
            );
          }
        }
      } catch (e) {
        console.error(`[reprocess-unprocessed] email_id=${raw.id} error=${e}`);
      }
    }

    return new Response(JSON.stringify({ processed }), {
      headers: { 'content-type': 'application/json' },
      status: 200,
    });
  };
}

if (import.meta.main) {
  const { createClient } = await import('jsr:@supabase/supabase-js@2');
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!;
  const handler = createHandler({
    supabase,
    fetch,
    openAiApiKey: OPENAI_API_KEY,
    serviceRoleKey: SERVICE_ROLE,
  });
  Deno.serve(handler);
}
