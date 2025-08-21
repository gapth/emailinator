// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

// Supabase client (service role for server-side usage)
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

// OpenAI
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const MODEL_NAME = "gpt-4.1-mini";

const TASK_SCHEMA = {
  name: "tasks_list",
  schema: {
    $schema: "https://json-schema.org/draft/2020-12/schema",
    title: "Extracted School Tasks",
    description:
      "A deduplicated, grouped list of tasks. If several lines describe the same overall activity (e.g., multiple retreat forms), merge them into one task and enumerate details in `description`.",
    type: "object",
    properties: {
      tasks: {
        type: "array",
        description:
          "A deduplicated, grouped list of tasks. If several lines describe the same overall activity, merge them and enumerate details in `description`.",
        items: {
          type: "object",
          additionalProperties: false,
          description:
            "One actionable item that a parent and/or student must complete, attend, or prepare for.",
          properties: {
            title: {
              type: "string",
              description:
                "Short (less than 30 characters) topic-only label for grouping and future matching. Do NOT include verbs if avoidable. Examples: 'Permission form', 'Tie Ceremony', 'Picture Day', 'Athletics forms', 'Locker assignments'.",
            },
            description: {
              type: "string",
              description:
                "Concise but complete summary incl. who/what/where/when and options; list sub-steps and extra dates if merged.",
            },
            due_date: {
              type: "string",
              format: "date",
              description:
                "YYYY-MM-DD deadline if explicitly stated; otherwise omit.",
            },
            consequence_if_ignore: {
              type: "string",
              description:
                "Natural-language consequence; infer if implicit.",
            },
            parent_action: {
              type: "string",
              enum: [
                "NONE",
                "SUBMIT",
                "SIGN",
                "PAY",
                "PURCHASE",
                "ATTEND",
                "TRANSPORT",
                "VOLUNTEER",
                "OTHER",
              ],
              description:
                "Parent’s single action. If multiple implied, choose one by priority: ATTEND > PAY > SUBMIT > SIGN > PURCHASE > TRANSPORT > VOLUNTEER > OTHER > NONE.",
            },
            parent_requirement_level: {
              type: "string",
              enum: ["NONE", "OPTIONAL", "VOLUNTEER", "MANDATORY"],
              description:
                "MANDATORY if required or a consequence stated; VOLUNTEER if explicitly seeking volunteers; OPTIONAL if encouraged; NONE if no parent action.",
            },
            student_action: {
              type: "string",
              enum: [
                "NONE",
                "SUBMIT",
                "ATTEND",
                "SETUP",
                "BRING",
                "PREPARE",
                "WEAR",
                "COLLECT",
                "OTHER",
              ],
              description:
                "Student’s single action. If multiple implied, choose one by priority: ATTEND > SUBMIT > SETUP > WEAR > BRING > COLLECT > PREPARE > OTHER > NONE.",
            },
            student_requirement_level: {
              type: "string",
              enum: ["NONE", "OPTIONAL", "VOLUNTEER", "MANDATORY"],
              description:
                "MANDATORY if required or a consequence stated; VOLUNTEER if student volunteering; OPTIONAL if encouraged; NONE if no student action.",
            },
          },
          required: ["title"],
        },
      },
    },
    required: ["tasks"],
    additionalProperties: false,
  },
};

async function extractDeduplicatedTasks(
  emailText: string,
  existingTasks: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  const prompt =
    "You are a careful assistant for a busy parent.\n" +
    "You are given an existing list of tasks and a new email.\n" +
    "Combine the existing tasks with any tasks found in the email, merging entries that describe the same activity.\n" +
    "Return the full deduplicated list of tasks.\n" +
    "Only include actionable items (forms, payments, events, purchases, transport, volunteering).\n" +
    "If an event requires attire, do not create a separate task for clothing; note attire inside `description`.\n" +
    "Return only valid JSON that conforms to the provided JSON Schema. No prose.";

  const body = {
    model: MODEL_NAME,
    messages: [
      { role: "system", content: prompt },
      {
        role: "user",
        content:
          `Existing tasks:\n${JSON.stringify({ tasks: existingTasks })}\n\nEmail:\n${emailText}`,
      },
    ],
    response_format: { type: "json_schema", json_schema: TASK_SCHEMA },
  };

  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    throw new Error(await resp.text());
  }

  const data = await resp.json();
  const content = data.choices?.[0]?.message?.content ?? "{}";
  return JSON.parse(content).tasks ?? [];
}

type InboundPayload = {
  from_email?: string;
  to_email?: string;
  subject?: string;
  text_body?: string;
  html_body?: string;
  provider_meta?: Record<string, any>;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  // Authenticate using the caller's Supabase JWT
  const auth = req.headers.get("authorization")?.split("Bearer ")[1];
  if (!auth) return new Response("Unauthorized", { status: 401 });

  const { data: { user }, error: authError } = await supabase.auth.getUser(auth);
  if (authError || !user) return new Response("Unauthorized", { status: 401 });

  try {
    const payload = await req.json() as InboundPayload;

    const user_id = user.id;
    // Store raw email and grab ID for task linking
    const { data: rawData, error: rawError } = await supabase
      .from("raw_emails")
      .insert({
        user_id,
        from_email: payload.from_email ?? null,
        to_email: payload.to_email ?? null,
        subject: payload.subject ?? null,
        text_body: payload.text_body ?? null,
        html_body: payload.html_body ?? null,
        provider_meta: payload.provider_meta ?? {},
      })
      .select("id")
      .single();

    if (rawError) return new Response(rawError.message, { status: 500 });

    const emailText = payload.text_body ?? payload.html_body ?? "";

    const { data: existing, error: existingError } = await supabase
      .from("tasks")
      .select(
        "title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level",
      )
      .eq("user_id", user_id);

    if (existingError) return new Response(existingError.message, { status: 500 });

    const tasks = await extractDeduplicatedTasks(emailText, existing ?? []);

    // Replace existing tasks with deduplicated list
    const { error: delError } = await supabase
      .from("tasks")
      .delete()
      .eq("user_id", user_id);
    if (delError) return new Response(delError.message, { status: 500 });

    if (tasks.length > 0) {
      const rows = tasks.map((t: any) => ({
        user_id,
        email_id: rawData.id,
        title: t.title,
        description: t.description ?? null,
        due_date: t.due_date ?? null,
        consequence_if_ignore: t.consequence_if_ignore ?? null,
        parent_action: t.parent_action ?? null,
        parent_requirement_level: t.parent_requirement_level ?? null,
        student_action: t.student_action ?? null,
        student_requirement_level: t.student_requirement_level ?? null,
        status: "PENDING",
      }));

      const { error: insertError } = await supabase
        .from("tasks")
        .insert(rows);
      if (insertError) return new Response(insertError.message, { status: 500 });
    }

    return new Response(JSON.stringify({ task_count: tasks.length }), {
      headers: { "content-type": "application/json" },
      status: 200,
    });
  } catch (e) {
    return new Response(`Bad Request: ${e}`, { status: 400 });
  }
});
