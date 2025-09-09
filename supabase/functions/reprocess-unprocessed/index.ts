import {
  extractDeduplicatedTasks,
  replaceTasksAndUpdateEmail,
  chooseEmailText,
  INPUT_NANO_USD_PER_TOKEN,
  OUTPUT_NANO_USD_PER_TOKEN,
} from '../_shared/task-utils.ts';

export interface Deps {
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
      .eq('status', 'UNPROCESSED');
    if (error) return new Response(error.message, { status: 500 });

    let processed = 0;
    for (const raw of raws as any[]) {
      try {
        const user_id = raw.user_id;
        const emailText = chooseEmailText(raw);

        const { data: budgetRow, error: budgetError } = await supabase
          .from('processing_budgets')
          .select('remaining_nano_usd')
          .eq('user_id', user_id)
          .single();
        const remainingBudget = budgetError ? 0 : budgetRow.remaining_nano_usd;
        if (remainingBudget <= 0) continue;

        const { data: existingRaw, error: existingError } = await supabase
          .from('user_tasks')
          .select('*')
          .eq('user_id', user_id)
          .eq('state', 'OPEN');
        if (existingError) continue;

        const existingRows = Array.isArray(existingRaw) ? existingRaw : [];
        const existingForAi = existingRows.map((t: any) => ({
          title: t.title,
          description: t.description ?? null,
          due_date: t.due_date ?? null,
          parent_action: t.parent_action ?? null,
          parent_requirement_level: t.parent_requirement_level ?? null,
          student_action: t.student_action ?? null,
          student_requirement_level: t.student_requirement_level ?? null,
        }));

        const { tasks, promptTokens, completionTokens, rawContent } =
          await extractDeduplicatedTasks(
            supabase,
            fetch,
            openAiApiKey,
            emailText,
            existingForAi,
            user_id,
            raw.id
          );

        const result = await replaceTasksAndUpdateEmail({
          supabase,
          userId: user_id,
          rawEmailId: raw.id,
          tasks,
          existingRows,
          promptTokens,
          completionTokens,
          rawContent,
          logPrefix: 'reprocess-unprocessed',
        });
        if (result.success) {
          processed++;
          const totalCost =
            promptTokens * INPUT_NANO_USD_PER_TOKEN +
            completionTokens * OUTPUT_NANO_USD_PER_TOKEN;

          // Atomically decrement the remaining budget using database function
          const { error: budgetUpdateError } = await supabase.rpc(
            'decrement_processing_budget',
            {
              p_user_id: user_id,
              p_amount: totalCost,
            }
          );

          if (budgetUpdateError) {
            console.error(
              `[reprocess-unprocessed] Budget update error for user ${user_id}: ${budgetUpdateError.message}`
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
