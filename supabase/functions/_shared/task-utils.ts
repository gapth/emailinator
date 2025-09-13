import { runModel } from './ai.ts';

export const TEXT_BODY_MIN_RATIO_OF_HTML = 0.3; // Use text/plain only if it's at least 30% of the HTML length

export const TASK_SCHEMA = {
  name: 'tasks_list',
  schema: {
    $schema: 'https://json-schema.org/draft/2020-12/schema',
    title: 'Extracted School Tasks',
    description:
      'A deduplicated, grouped list of tasks. If several lines describe the same overall activity (e.g., multiple retreat forms), merge them into one task and enumerate details in `description`.',
    type: 'object',
    properties: {
      tasks: {
        type: 'array',
        description:
          'A deduplicated, grouped list of tasks. If several lines describe the same overall activity, merge them and enumerate details in `description`.',
        items: {
          type: 'object',
          additionalProperties: false,
          description:
            'One actionable item that a parent and/or student must complete, attend, or prepare for.',
          properties: {
            title: {
              type: 'string',
              description:
                "Short (less than 30 characters) topic-only label for grouping and future matching. Do NOT include verbs if avoidable. Examples: 'Permission form', 'Tie Ceremony', 'Picture Day', 'Athletics forms', 'Locker assignments'.",
            },
            description: {
              type: 'string',
              description:
                'Concise but complete summary incl. who/what/where/when and options; list sub-steps and extra dates if merged.',
            },
            due_date: {
              type: 'string',
              format: 'date',
              description:
                'YYYY-MM-DD deadline if explicitly stated; otherwise omit.',
            },
            parent_action: {
              type: 'string',
              enum: [
                'NONE',
                'SUBMIT',
                'SIGN',
                'PAY',
                'PURCHASE',
                'ATTEND',
                'TRANSPORT',
                'VOLUNTEER',
                'OTHER',
              ],
              description:
                'Parent’s single action. If multiple implied, choose one by priority: ATTEND > PAY > SUBMIT > SIGN > PURCHASE > TRANSPORT > VOLUNTEER > OTHER > NONE.',
            },
            parent_requirement_level: {
              type: 'string',
              enum: ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'],
              description:
                'MANDATORY if required or a consequence stated; VOLUNTEER if explicitly seeking volunteers; OPTIONAL if encouraged; NONE if no parent action.',
            },
            student_action: {
              type: 'string',
              enum: [
                'NONE',
                'SUBMIT',
                'ATTEND',
                'SETUP',
                'BRING',
                'PREPARE',
                'WEAR',
                'COLLECT',
                'OTHER',
              ],
              description:
                'Student’s single action. If multiple implied, choose one by priority: ATTEND > SUBMIT > SETUP > WEAR > BRING > COLLECT > PREPARE > OTHER > NONE.',
            },
            student_requirement_level: {
              type: 'string',
              enum: ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'],
              description:
                'MANDATORY if required or a consequence stated; VOLUNTEER if student volunteering; OPTIONAL if encouraged; NONE if no student action.',
            },
          },
          required: ['title'],
        },
      },
    },
    required: ['tasks'],
    additionalProperties: false,
  },
};

export const PARENT_ACTIONS = [
  'NONE',
  'SUBMIT',
  'SIGN',
  'PAY',
  'PURCHASE',
  'ATTEND',
  'TRANSPORT',
  'VOLUNTEER',
  'OTHER',
];
export const REQUIREMENT_LEVELS = [
  'NONE',
  'OPTIONAL',
  'VOLUNTEER',
  'MANDATORY',
];
export const STUDENT_ACTIONS = [
  'NONE',
  'SUBMIT',
  'ATTEND',
  'SETUP',
  'BRING',
  'PREPARE',
  'WEAR',
  'COLLECT',
  'OTHER',
];

// deno-lint-ignore no-explicit-any
export function sanitizeTasks(raw: any[]): Record<string, unknown>[] {
  return (Array.isArray(raw) ? raw : [])
    .map((t) => {
      if (!t || typeof t.title !== 'string' || t.title.trim() === '')
        return null;
      const task: Record<string, unknown> = { title: t.title };
      task.description =
        typeof t.description === 'string' && t.description.trim() !== ''
          ? t.description
          : null;
      if (
        typeof t.due_date === 'string' &&
        /^\d{4}-\d{2}-\d{2}$/.test(t.due_date)
      ) {
        task.due_date = t.due_date;
      } else {
        task.due_date = null;
      }
      task.parent_action = PARENT_ACTIONS.includes(t.parent_action)
        ? t.parent_action
        : null;
      task.parent_requirement_level = REQUIREMENT_LEVELS.includes(
        t.parent_requirement_level
      )
        ? t.parent_requirement_level
        : null;
      task.student_action = STUDENT_ACTIONS.includes(t.student_action)
        ? t.student_action
        : null;
      task.student_requirement_level = REQUIREMENT_LEVELS.includes(
        t.student_requirement_level
      )
        ? t.student_requirement_level
        : null;
      return task;
    })
    .filter(Boolean) as Record<string, unknown>[];
}

export async function extractNewTasks(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  fetchFn: typeof fetch,
  openAiApiKey: string,
  emailText: string,
  existingTasks: Record<string, unknown>[],
  userId: string,
  emailId?: string | number
): Promise<{
  tasks: Record<string, unknown>[];
  promptTokens: number;
  completionTokens: number;
  totalCostNano: number;
  rawContent: string;
}> {
  const userContent = `Existing tasks:\n${JSON.stringify({ tasks: existingTasks })}\n\nEmail:\n${emailText}`;
  const responseFormat = { type: 'json_schema', json_schema: TASK_SCHEMA };

  const { content, aiInvocation } = await runModel({
    supabase,
    fetch: fetchFn,
    openAiApiKey,
    userId,
    // deno-lint-ignore no-explicit-any
    emailId: (emailId as any) ?? undefined,
    userContent,
    responseFormat,
  });

  console.info(
    `[task-utils] user=${userId} API cost (USD): ${(aiInvocation.total_cost_nano / 1e9).toFixed(6)} (prompt=${aiInvocation.request_tokens}, completion=${aiInvocation.response_tokens})`
  );

  // deno-lint-ignore no-explicit-any
  let parsed: any[] = [];
  try {
    parsed = JSON.parse(content).tasks ?? [];
  } catch (_e) {
    parsed = [];
  }
  const tasks = sanitizeTasks(parsed);
  return {
    tasks,
    promptTokens: aiInvocation.request_tokens,
    completionTokens: aiInvocation.response_tokens,
    totalCostNano: aiInvocation.total_cost_nano,
    rawContent: content,
  };
}

export function chooseEmailText(payload: {
  TextBody?: string;
  HtmlBody?: string;
  text_body?: string;
  html_body?: string;
  textBody?: string;
  htmlBody?: string;
}) {
  // Accept multiple casing / naming variants from different sources (Postmark, DB rows, internal JSON)
  const plain = payload.TextBody ?? payload.text_body ?? payload.textBody ?? '';
  const html = payload.HtmlBody ?? payload.html_body ?? payload.htmlBody ?? '';
  return plain &&
    (html.length === 0 ||
      plain.length >= TEXT_BODY_MIN_RATIO_OF_HTML * html.length)
    ? plain
    : html || '';
}

/**
 * Get all open tasks for a user for AI deduplication.
 * Query tasks table directly and join with user_task_states to get state.
 * Filter for OPEN tasks (includes tasks with no state record, which default to OPEN).
 * The user_tasks view cannot be used here because it has RLS, but this function
 * is running with service role, so auth.user_id is not available.
 */
export async function getOpenTasksForDeduplication(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string
): Promise<{ tasks: Record<string, unknown>[]; error?: string }> {
  const { data: existingRaw, error: existingError } = await supabase
    .from('tasks')
    .select(
      `
      *,
      user_task_states!left (
        state
      )
    `
    )
    .eq('user_id', userId)
    .or('state.is.null,state.eq.OPEN', { foreignTable: 'user_task_states' });

  if (existingError) {
    return { tasks: [], error: existingError.message };
  }

  const existingRows = Array.isArray(existingRaw) ? existingRaw : [];
  // deno-lint-ignore no-explicit-any
  const existingForAi = existingRows.map((t: any) => ({
    title: t.title,
    description: t.description ?? null,
    due_date: t.due_date ?? null,
    parent_action: t.parent_action ?? null,
    parent_requirement_level: t.parent_requirement_level ?? null,
    student_action: t.student_action ?? null,
    student_requirement_level: t.student_requirement_level ?? null,
  }));

  return { tasks: existingForAi };
}

/**
 * Get the remaining processing budget for a user.
 */
export async function getUserProcessingBudget(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string
): Promise<{ budget: number; error?: string }> {
  const { data: budgetRow, error: budgetError } = await supabase
    .from('processing_budgets')
    .select('remaining_nano_usd')
    .eq('user_id', userId)
    .single();

  if (budgetError) {
    return { budget: 0, error: budgetError.message };
  }

  return { budget: budgetRow.remaining_nano_usd };
}

/**
 * Atomically decrement the processing budget for a user.
 */
export async function decrementProcessingBudget(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  amount: number,
  logPrefix: string
): Promise<{ success: boolean; error?: string }> {
  const { error: budgetUpdateError } = await supabase.rpc(
    'decrement_processing_budget',
    {
      p_user_id: userId,
      p_amount: amount,
    }
  );

  if (budgetUpdateError) {
    console.error(
      `[${logPrefix}] Budget update error for user ${userId}: ${budgetUpdateError.message}`
    );
    return { success: false, error: budgetUpdateError.message };
  }

  return { success: true };
}

export async function addNewTasksAndUpdateEmail({
  supabase,
  userId,
  rawEmailId,
  newTasks,
  existingTasksCount,
  _promptTokens,
  _completionTokens,
  rawContent,
  logPrefix,
}: {
  // deno-lint-ignore no-explicit-any
  supabase: any;
  userId: string;
  rawEmailId: string | number;
  newTasks: Record<string, unknown>[];
  existingTasksCount: number;
  _promptTokens: number;
  _completionTokens: number;
  rawContent: string;
  logPrefix: string;
}): Promise<{ success: boolean; taskCount: number; error?: string }> {
  // Only add new tasks - do not delete any existing tasks
  if (newTasks.length > 0) {
    const rows = newTasks.map((t: Record<string, unknown>) => ({
      user_id: userId,
      email_id: rawEmailId,
      title: t.title,
      description: t.description ?? null,
      due_date: t.due_date ?? null,
      parent_action: t.parent_action ?? null,
      parent_requirement_level: t.parent_requirement_level ?? null,
      student_action: t.student_action ?? null,
      student_requirement_level: t.student_requirement_level ?? null,
    }));

    const { error: insertError } = await supabase.from('tasks').insert(rows);
    if (insertError) {
      console.error(
        `[${logPrefix}] user=${userId} task_insert_failed: ${insertError.message} openai_response=${rawContent}`
      );
      return { success: false, taskCount: 0, error: insertError.message };
    }
  }

  const finalTaskCount = existingTasksCount + newTasks.length;
  const { error: updateError } = await supabase
    .from('raw_emails')
    .update({
      tasks_after: finalTaskCount,
      status: 'UPDATED_TASKS',
    })
    .eq('id', rawEmailId);

  if (updateError) {
    console.error(
      `[${logPrefix}] user=${userId} raw_email_update_failed: ${updateError.message} openai_response=${rawContent}`
    );
    // Delete the newly inserted tasks to rollback
    await supabase
      .from('tasks')
      .delete()
      .eq('user_id', userId)
      .eq('email_id', rawEmailId);
    return { success: false, taskCount: 0, error: updateError.message };
  }

  return { success: true, taskCount: newTasks.length };
}
