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
function createSupabaseStub(initialTasks: any[] = []) {
  const state = { raw_emails: [], tasks: [...initialTasks] };
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
        };
      }
      if (table === "tasks") {
        return {
          select() {
            return {
              eq(_: string, value: string) {
                const data = state.tasks
                  .filter((t) => t.user_id === value)
                  .map(({ user_id, ...rest }) => rest);
                return { data, error: null };
              },
            };
          },
          delete() {
            return {
              eq(_: string, value: string) {
                state.tasks = state.tasks.filter((t) => t.user_id !== value);
                return { error: null };
              },
            };
          },
          insert(rows: any[]) {
            state.tasks.push(...rows);
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
        return { choices: [{ message: { content: JSON.stringify({ tasks: returnTasks }) } }] };
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

test("passes existing tasks and stores new set", async () => {
  const existing = [
    { user_id: "user-1", title: "Old Task" },
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
});

test("keeps DB unchanged if extraction fails", async () => {
  const existing = [
    { user_id: "user-1", title: "Keep" },
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

test("handles zero tasks correctly", async () => {
  const existing = [
    { user_id: "user-1", title: "Old" },
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
