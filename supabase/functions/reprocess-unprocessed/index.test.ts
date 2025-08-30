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

function createSupabaseStub(initialRaw: any[] = [], initialTasks: any[] = [], budgetNanoUsd = 1_000_000_000) {
  const state = { raw_emails: [...initialRaw], tasks: [...initialTasks], budget: budgetNanoUsd };
  return {
    state,
    from(table: string) {
      if (table === "raw_emails") {
        return {
          select() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                this._filters.push((r: any) => r[field] === value);
                return builder;
              },
              then(resolve: any) {
                const data = state.raw_emails.filter((r) => builder._filters.every((f: any) => f(r)));
                return resolve({ data, error: null });
              },
            };
            return builder;
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
        };
      }
      if (table === "user_tasks") {
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
              in(field: string, values: any[]) {
                builder._filters.push((r: any) => values.includes(r[field]));
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
            state.tasks.push(...rows);
            return { error: null };
          },
        };
      }
      if (table === "processing_budgets") {
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

function createFetchStub(returnTasks: any[]) {
  const calls: any[] = [];
  const fetchFn = async (_url: string, init: any) => {
    calls.push({ url: _url, init });
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

test("processes UNPROCESSED raw emails", async () => {
  const rawEmails = [
    { id: 1, user_id: "user-1", text_body: "email", html_body: null, status: "UNPROCESSED" },
  ];
  const tasks = [
    { id: 1, user_id: "user-1", title: "Old", state: "OPEN" },
  ];
  const supabase = createSupabaseStub(rawEmails, tasks);
  const fetchStub = createFetchStub([{ title: "New" }]);
  const handler = createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: "test",
    serviceRoleKey: "svc",
  });

  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer svc" },
    }),
  );
  assertEquals(res.status, 200);
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, "New");
  assertEquals(supabase.state.raw_emails[0].status, "UPDATED_TASKS");
  const body = await res.json();
  assertEquals(body.processed, 1);
});

test("requires service role key", async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: "test",
    serviceRoleKey: "svc",
  });
  const res = await handler(new Request("http://localhost", { method: "POST" }));
  assertEquals(res.status, 401);
});

test("skips when budget depleted", async () => {
  const rawEmails = [
    { id: 1, user_id: "user-1", text_body: "email", html_body: null, status: "UNPROCESSED" },
  ];
  const supabase = createSupabaseStub(rawEmails, [], 0);
  const fetchStub = createFetchStub([{ title: "New" }]);
  const handler = createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: "test",
    serviceRoleKey: "svc",
  });
  const res = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { authorization: "Bearer svc" },
    }),
  );
  assertEquals(res.status, 200);
  assertEquals(fetchStub.calls.length, 0);
  assertEquals(supabase.state.raw_emails[0].status, "UNPROCESSED");
  const body = await res.json();
  assertEquals(body.processed, 0);
});
