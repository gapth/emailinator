// Minimal assertion helpers
function assert(cond: boolean, msg = "Assertion failed") {
  if (!cond) throw new Error(msg);
}
function assertEquals(actual: unknown, expected: unknown, msg = "") {
  if (actual !== expected) {
    throw new Error(msg || `Expected ${expected}, got ${actual}`);
  }
}

import { createHandler } from "./index.ts";
import { test } from "node:test";

// Supabase stub factory
function createSupabaseStub(initialTasks: any[] = [], opts: { failTaskInsert?: boolean; budgetNanoUsd?: number } = {}) {
  const state = { raw_emails: [], tasks: [...initialTasks], budget: opts.budgetNanoUsd ?? 1_000_000_000 };
  let insertAttempts = 0;
  return {
    state,
    auth: {
      async getUser(token: string) {
        if (token === "valid") {
          return { data: { user: { id: "user-1" } }, error: null };
        }
        return { data: { user: null }, error: new Error("invalid token") };
      },
    },
    from(table: string) {
      if (table === "raw_emails") {
        return {
          insert(row: any) {
            const id = state.raw_emails.length + 1;
            state.raw_emails.push({ id, ...row });
            return {
              select() {
                return {
                  single() {
                    return { data: { id }, error: null };
                  },
                };
              },
            };
          },
          update(values: any) {
            const builder: any = {
              _updates: values,
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                this._filters.push((r: any) => r[field] === value);
                return builder;
              },
              then(resolve: any) {
                state.raw_emails.filter((r) => builder._filters.every((f: any) => f(r))).forEach((r) => {
                  Object.assign(r, builder._updates);
                });
                return resolve({ data: null, error: null });
              },
            };
            return builder;
          },
          select() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                this._filters.push((r: any) => r[field] === value);
                return builder;
              },
              is(field: string, value: any) {
                this._filters.push((r: any) => (value === null ? r[field] === null || r[field] === undefined : r[field] === value));
                return builder;
              },
              then(resolve: any) {
                const data = state.raw_emails.filter((r) => builder._filters.every((f: any) => f(r)));
                return resolve({ data, error: null });
              },
            };
            return builder;
          },
        };
      }
      if (table === "tasks") {
        return {
          select() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                builder._filters.push((r: any) => r[field] === value);
                return builder;
              },
              then(resolve: any) {
                const data = state.tasks.filter((t) => builder._filters.every((f: any) => f(t)));
                return resolve({ data, error: null });
              },
            };
            return builder;
          },
          delete() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                builder._filters.push((r: any) => r[field] === value);
                return builder;
              },
              then(resolve: any) {
                state.tasks = state.tasks.filter((t) => !builder._filters.every((f: any) => f(t)));
                return resolve({ error: null });
              },
            };
            return builder;
          },
          insert(rows: any[]) {
            insertAttempts++;
            if (opts.failTaskInsert && insertAttempts === 1) {
              return { error: new Error("insert fail") };
            }
            state.tasks.push(...rows);
            return { error: null };
          },
        };
      }
      if (table === "openai_budget") {
        return {
          select() {
            const builder: any = {
              eq(_f: string, _v: any) { return builder; },
              single() {
                if (state.budget === undefined) {
                  return { data: null, error: { code: "PGRST116" } };
                }
                return { data: { remaining_nano_usd: state.budget }, error: null };
              },
            };
            return builder;
          },
          upsert(row: any) {
            state.budget = row.remaining_nano_usd;
            return { error: null };
          },
        };
      }
      throw new Error("unknown table");
    },
  };
}

function createFetchStub(returnTasks: any[], opts: { fail?: boolean } = {}) {
  const calls: any[] = [];
  const fetchFn = async (_url: string, init: any) => {
    calls.push({ url: _url, init });
    if (opts.fail) {
      return { ok: false, text: async () => "failure" };
    }
    return {
      ok: true,
      async json() {
        return {
          choices: [{ message: { content: JSON.stringify({ tasks: returnTasks }) } }],
          usage: { prompt_tokens: 1, completion_tokens: returnTasks.length },
        };
      },
    };
  };
  (fetchFn as any).calls = calls;
  return fetchFn as typeof fetch & { calls: any[] };
}

test("handles auth correctly", async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  let res = await handler(new Request("http://localhost", { method: "POST" }));
  assertEquals(res.status, 401);

  res = await handler(
    new Request("http://localhost", { method: "POST", headers: { authorization: "Bearer bad" } }),
  );
  assertEquals(res.status, 401);
});

test("hits OpenAI API to extract tasks", async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "hello" }),
    }),
  );
  assertEquals(res.status, 200);
  assertEquals(fetchStub.calls.length, 1);
});

test("skips processing when budget depleted", async () => {
  const supabase = createSupabaseStub([], { budgetNanoUsd: 0 });
  const fetchStub = createFetchStub([{ title: "New" }]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 200);
  assertEquals(fetchStub.calls.length, 0);
  assertEquals(supabase.state.raw_emails.length, 1);
  assertEquals(supabase.state.raw_emails[0].status, "UNPROCESSED");
});

test("passes existing tasks and stores new set", async () => {
  const existing = [
    { user_id: "user-1", title: "Old Task", status: "PENDING" },
  ];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([{ title: "New Task" }]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 200);
  assert(fetchStub.calls[0].init.body.includes("Old Task"));
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, "New Task");
  assertEquals(supabase.state.raw_emails[0].status, "UPDATED_TASKS");
  assertEquals(supabase.state.raw_emails[0].tasks_after, 1);
});

test("keeps DB unchanged if extraction fails", async () => {
  const existing = [
    { user_id: "user-1", title: "Keep", status: "PENDING" },
  ];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([], { fail: true });
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 400);
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, "Keep");
});

test("rolls back tasks if inserting new tasks fails", async () => {
  const existing = [
    { user_id: "user-1", title: "Old", status: "PENDING" },
  ];
  const supabase = createSupabaseStub(existing, { failTaskInsert: true });
  const fetchStub = createFetchStub([{ title: "New" }]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 500);
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, "Old");
  assertEquals(supabase.state.raw_emails[0].status, "UNPROCESSED");
});

test("sanitizes invalid task fields", async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([
    {
      title: "Test",
      due_date: "",
      parent_action: "FLY",
      student_action: "",
      parent_requirement_level: "MUST",
      student_requirement_level: "MANDATORY",
    },
  ]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 200);
  const stored = supabase.state.tasks[0];
  assertEquals(stored.due_date, null);
  assertEquals(stored.parent_action, null);
  assertEquals(stored.student_action, null);
  assertEquals(stored.parent_requirement_level, null);
  assertEquals(stored.student_requirement_level, "MANDATORY");
});

test("logs OpenAI response when task insert fails", async () => {
  const existing = [
    { user_id: "user-1", title: "Old", status: "PENDING" },
  ];
  const supabase = createSupabaseStub(existing, { failTaskInsert: true });
  const fetchStub = createFetchStub([{ title: "New" }]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const errors: string[] = [];
  const orig = console.error;
  console.error = (...args: any[]) => {
    errors.push(args.join(" "));
  };
  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  console.error = orig;
  assertEquals(res.status, 500);
  const combined = errors.join(" ");
  assert(combined.includes("openai_response"));
  assert(combined.includes("New"));
});

test("handles zero tasks correctly", async () => {
  const existing = [
    { user_id: "user-1", title: "Old", status: "PENDING" },
  ];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.task_count, 0);
  assertEquals(supabase.state.tasks.length, 0);
});

test("detects duplicate emails by Message-ID", async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const payload = {
    text_body: "email",
    message_id: "<id-1>",
    date: "Mon, 20 Jan 2025 10:00:00 +0000",
  };

  let res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify(payload),
    }),
  );
  assertEquals(res.status, 200);

  res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify(payload),
    }),
  );
  assertEquals(res.status, 409);
  assertEquals(supabase.state.raw_emails.length, 1);
});

test("dedupes emails without Message-ID using other fields", async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const payload = {
    text_body: "email",
    from_email: "a@example.com",
    to_email: "b@example.com",
    subject: "Hello",
    date: "Mon, 20 Jan 2025 10:00:00 +0000",
  };

  let res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify(payload),
    }),
  );
  assertEquals(res.status, 200);

  res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify(payload),
    }),
  );
  assertEquals(res.status, 409);
  assertEquals(supabase.state.raw_emails.length, 1);
});

test("only pending tasks are deduped", async () => {
  const existing = [
    { user_id: "user-1", title: "Pending", status: "PENDING" },
    { user_id: "user-1", title: "Done", status: "DONE" },
  ];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([{ title: "New" }]);
  const handler = createHandler({ supabase, fetch: fetchStub, openAiApiKey: "test" });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: JSON.stringify({ text_body: "email" }),
    }),
  );
  assertEquals(res.status, 200);
  const body = fetchStub.calls[0].init.body;
  assert(body.includes("Pending"));
  assert(!body.includes("Done"));
  const titles = supabase.state.tasks.map((t) => t.title).sort();
  assert(titles.includes("Done"));
  assert(titles.includes("New"));
  assert(!titles.includes("Pending"));
});
