export const MODEL_NAME = 'gpt-4.1-mini';
export const INPUT_NANO_USD_PER_TOKEN = 400;
export const OUTPUT_NANO_USD_PER_TOKEN = 1600;
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
            consequence_if_ignore: {
              type: 'string',
              description: 'Natural-language consequence; infer if implicit.',
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
      task.consequence_if_ignore =
        typeof t.consequence_if_ignore === 'string' &&
        t.consequence_if_ignore.trim() !== ''
          ? t.consequence_if_ignore
          : null;
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

export async function extractDeduplicatedTasks(
  fetchFn: typeof fetch,
  openAiApiKey: string,
  emailText: string,
  existingTasks: Record<string, unknown>[],
  userId: string
): Promise<{
  tasks: Record<string, unknown>[];
  promptTokens: number;
  completionTokens: number;
  rawContent: string;
}> {
  const prompt =
    'You are a careful assistant for a busy parent.\n' +
    'You are given an existing list of tasks and a new email.\n' +
    'Combine the existing tasks with any tasks found in the email, merging entries that describe the same activity.\n' +
    'Return the full deduplicated list of tasks.\n' +
    'Only include actionable items (forms, payments, events, purchases, transport, volunteering).\n' +
    'If an event requires attire, do not create a separate task for clothing; note attire inside `description`.\n' +
    'Return only valid JSON that conforms to the provided JSON Schema. No prose.';

  const body = {
    model: MODEL_NAME,
    messages: [
      { role: 'system', content: prompt },
      {
        role: 'user',
        content: `Existing tasks:\n${JSON.stringify({ tasks: existingTasks })}\n\nEmail:\n${emailText}`,
      },
    ],
    response_format: { type: 'json_schema', json_schema: TASK_SCHEMA },
  };

  const resp = await fetchFn('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${openAiApiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    throw new Error(await resp.text());
  }

  const data = await resp.json();

  const promptTokens = data?.usage?.prompt_tokens ?? 0;
  const completionTokens = data?.usage?.completion_tokens ?? 0;
  const apiCostNano =
    promptTokens * INPUT_NANO_USD_PER_TOKEN +
    completionTokens * OUTPUT_NANO_USD_PER_TOKEN;
  console.info(
    `[task-utils] user=${userId} API cost (USD): ${(apiCostNano / 1e9).toFixed(6)} (prompt=${promptTokens}, completion=${completionTokens})`
  );

  const content = data.choices?.[0]?.message?.content ?? '{}';
  let parsed: any[] = [];
  try {
    parsed = JSON.parse(content).tasks ?? [];
  } catch (_e) {
    parsed = [];
  }
  const tasks = sanitizeTasks(parsed);
  return { tasks, promptTokens, completionTokens, rawContent: content };
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

export async function replaceTasksAndUpdateEmail({
  supabase,
  userId,
  rawEmailId,
  tasks,
  existingRows,
  promptTokens,
  completionTokens,
  rawContent,
  logPrefix,
}: {
  supabase: any;
  userId: string;
  rawEmailId: number;
  tasks: Record<string, unknown>[];
  existingRows: any[];
  promptTokens: number;
  completionTokens: number;
  rawContent: string;
  logPrefix: string;
}): Promise<{ success: boolean; taskCount: number; error?: string }> {
  const inputCostNano = promptTokens * INPUT_NANO_USD_PER_TOKEN;
  const outputCostNano = completionTokens * OUTPUT_NANO_USD_PER_TOKEN;

  // Delete exactly the tasks that were passed in (more reliable than duplicating query logic)
  if (existingRows.length > 0) {
    const existingIds = existingRows
      .map((row: any) => row.id)
      .filter((id: any) => id != null);
    if (existingIds.length > 0) {
      const { error: delError } = await supabase
        .from('tasks')
        .delete()
        .in('id', existingIds);
      if (delError)
        return { success: false, taskCount: 0, error: delError.message };
    }
  }

  if (tasks.length > 0) {
    const rows = tasks.map((t: any) => ({
      user_id: userId,
      email_id: rawEmailId,
      title: t.title,
      description: t.description ?? null,
      due_date: t.due_date ?? null,
      consequence_if_ignore: t.consequence_if_ignore ?? null,
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
      // Restore the exact rows that were deleted
      if (existingRows.length > 0) {
        const restoreRows = existingRows.map(({ id, ...r }: any) => r);
        await supabase.from('tasks').insert(restoreRows);
      }
      return { success: false, taskCount: 0, error: insertError.message };
    }
  }

  const { error: updateError } = await supabase
    .from('raw_emails')
    .update({
      tasks_after: tasks.length,
      status: 'UPDATED_TASKS',
      openai_input_cost_nano_usd: inputCostNano,
      openai_output_cost_nano_usd: outputCostNano,
    })
    .eq('id', rawEmailId);

  if (updateError) {
    console.error(
      `[${logPrefix}] user=${userId} raw_email_update_failed: ${updateError.message} openai_response=${rawContent}`
    );
    // Delete the newly inserted tasks and restore the original ones
    await supabase
      .from('tasks')
      .delete()
      .eq('user_id', userId)
      .eq('email_id', rawEmailId);
    if (existingRows.length > 0) {
      const restoreRows = existingRows.map(({ id, ...r }: any) => r);
      await supabase.from('tasks').insert(restoreRows);
    }
    return { success: false, taskCount: 0, error: updateError.message };
  }

  return { success: true, taskCount: tasks.length };
}
