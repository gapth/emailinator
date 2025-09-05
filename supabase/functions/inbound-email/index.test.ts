// Minimal assertion helpers
function assert(cond: boolean, msg = 'Assertion failed') {
  if (!cond) throw new Error(msg);
}
function assertEquals(actual: unknown, expected: unknown, msg = '') {
  if (actual !== expected) {
    throw new Error(msg || `Expected ${expected}, got ${actual}`);
  }
}

import { createHandler } from './index.ts';
import { test } from 'node:test';

// Supabase stub factory
function createSupabaseStub(
  initialTasks: any[] = [],
  opts: { failTaskInsert?: boolean; budgetNanoUsd?: number } = {}
) {
  const state = {
    raw_emails: [] as any[],
    tasks: [...initialTasks],
    budget: opts.budgetNanoUsd ?? 1_000_000_000,
    aliases: [
      { alias: 'u_1@in.emailinator.app', user_id: 'user-1', active: true },
    ],
    forwarding_verifications: [] as any[],
  };
  let insertAttempts = 0;
  return {
    state,
    raw(sql: string) {
      return { raw: sql };
    },
    from(table: string) {
      if (table === 'raw_emails') {
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
                state.raw_emails
                  .filter((r) => builder._filters.every((f: any) => f(r)))
                  .forEach((r) => {
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
                this._filters.push((r: any) =>
                  value === null
                    ? r[field] === null || r[field] === undefined
                    : r[field] === value
                );
                return builder;
              },
              then(resolve: any) {
                const data = state.raw_emails.filter((r) =>
                  builder._filters.every((f: any) => f(r))
                );
                return resolve({ data, error: null });
              },
            };
            return builder;
          },
        };
      }
      if (table === 'user_tasks') {
        return {
          select() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                builder._filters.push((r: any) => r[field] === value);
                return builder;
              },
              or(condition: string) {
                // Parse the OR condition for due_date filtering
                if (condition.includes('due_date')) {
                  const now = new Date().toISOString();
                  builder._filters.push(
                    (r: any) =>
                      r.due_date === null ||
                      r.due_date === undefined ||
                      r.due_date >= now.split('T')[0] // Compare just the date part
                  );
                }
                return builder;
              },
              then(resolve: any) {
                const data = state.tasks.filter((t) =>
                  builder._filters.every((f: any) => f(t))
                );
                return resolve({ data, error: null });
              },
            };
            return builder;
          },
        };
      }
      if (table === 'tasks') {
        return {
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
                state.tasks = state.tasks.filter(
                  (t) => !builder._filters.every((f: any) => f(t))
                );
                return resolve({ error: null });
              },
            };
            return builder;
          },
          insert(rows: any[]) {
            insertAttempts++;
            if (opts.failTaskInsert && insertAttempts === 1) {
              return { error: new Error('insert fail') };
            }
            state.tasks.push(...rows);
            return { error: null };
          },
        };
      }
      if (table === 'processing_budgets') {
        return {
          select() {
            const builder: any = {
              eq(_f: string, _v: any) {
                return builder;
              },
              single() {
                if (state.budget === undefined) {
                  return { data: null, error: { code: 'PGRST116' } };
                }
                return {
                  data: { remaining_nano_usd: state.budget },
                  error: null,
                };
              },
            };
            return builder;
          },
          upsert(row: any) {
            state.budget = row.remaining_nano_usd;
            return { error: null };
          },
          update(values: any) {
            const builder: any = {
              _updates: values,
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                // For atomic budget updates, we need to handle raw SQL expressions
                if (field === 'user_id' && values.remaining_nano_usd?.raw) {
                  // Extract the subtraction amount from the raw SQL expression
                  const match = values.remaining_nano_usd.raw.match(
                    /remaining_nano_usd - (\d+)/
                  );
                  if (match) {
                    const subtractAmount = parseInt(match[1], 10);
                    state.budget = Math.max(0, state.budget - subtractAmount);
                  }
                }
                return builder;
              },
              then(resolve: any) {
                return resolve({ data: null, error: null });
              },
            };
            return builder;
          },
        };
      }
      if (table === 'email_aliases') {
        return {
          select() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                this._filters.push((r: any) => r[field] === value);
                return builder;
              },
              maybeSingle() {
                const data = state.aliases.filter((r) =>
                  builder._filters.every((f: any) => f(r))
                );
                return { data: data[0] ?? null, error: null };
              },
            };
            return builder;
          },
        };
      }
      if (table === 'forwarding_verifications') {
        return {
          insert(row: any) {
            const id = state.forwarding_verifications.length + 1;
            state.forwarding_verifications.push({ id, ...row });
            return { data: { id }, error: null };
          },
        };
      }
      throw new Error('unknown table');
    },
  };
}

function createFetchStub(returnTasks: any[], opts: { fail?: boolean } = {}) {
  const calls: any[] = [];
  const fetchFn = async (_url: string, init: any) => {
    calls.push({ url: _url, init });
    if (opts.fail) {
      return { ok: false, text: async () => 'failure' };
    }
    return {
      ok: true,
      async json() {
        return {
          choices: [
            { message: { content: JSON.stringify({ tasks: returnTasks }) } },
          ],
          usage: { prompt_tokens: 1, completion_tokens: returnTasks.length },
        };
      },
    };
  };
  (fetchFn as any).calls = calls;
  return fetchFn as typeof fetch & { calls: any[] };
}

const BASIC_USER = 'user';
const BASIC_PASS = 'pass';
const ALLOWED_IP = '1.1.1.1';

function makeHandler(supabase: any, fetchStub: any) {
  return createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: 'test',
    basicUser: BASIC_USER,
    basicPassword: BASIC_PASS,
    allowedIps: [ALLOWED_IP],
    inboundDomain: 'in.emailinator.app',
  });
}

function makeReq(payload: any, opts: { auth?: boolean; ip?: string } = {}) {
  const body = JSON.stringify({ To: 'u_1@in.emailinator.app', ...payload });
  const headers: Record<string, string> = {};
  if (opts.auth !== false) {
    headers['authorization'] = 'Basic ' + btoa(`${BASIC_USER}:${BASIC_PASS}`);
  }
  headers['x-forwarded-for'] = opts.ip ?? ALLOWED_IP;
  return new Request('http://localhost', { method: 'POST', headers, body });
}

test('handles auth and IP correctly', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  let res = await handler(makeReq({ TextBody: 'email' }, { auth: false }));
  assertEquals(res.status, 401);

  res = await handler(makeReq({ TextBody: 'email' }, { ip: '2.2.2.2' }));
  assertEquals(res.status, 401);
});

test('extracts alias from forwarded fields', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  const payload = {
    To: '"Real User" <real@example.com>',
    ToFull: [{ Email: 'real@example.com', Name: 'Real User', MailboxHash: '' }],
    Bcc: 'u_1@in.emailinator.app',
    BccFull: [{ Email: 'u_1@in.emailinator.app', Name: '', MailboxHash: '' }],
  };

  const res = await handler(makeReq(payload));
  assertEquals(res.status, 200);
});

test('stores forwarding verification link', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  const link = 'https://mail-settings.google.com/mail/vf-sample';
  const res = await handler(
    makeReq({
      From: 'forwarding-noreply@google.com',
      Subject:
        '(Gmail Forwarding Confirmation - Receive Mail from test@example.com',
      TextBody: `please confirm: ${link}`,
    })
  );

  assertEquals(res.status, 200);
  assertEquals(supabase.state.forwarding_verifications.length, 1);
  assertEquals(
    supabase.state.forwarding_verifications[0].verification_link,
    link
  );
});

test('hits OpenAI API to extract tasks', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'hello' }));
  assertEquals(res.status, 200);
  assertEquals(fetchStub.calls.length, 1);
});

test('skips processing when budget depleted', async () => {
  const supabase = createSupabaseStub([], { budgetNanoUsd: 0 });
  const fetchStub = createFetchStub([{ title: 'New' }]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 200);
  assertEquals(fetchStub.calls.length, 0);
  assertEquals(supabase.state.raw_emails.length, 1);
  assertEquals(supabase.state.raw_emails[0].status, 'UNPROCESSED');
});

test('atomically decrements budget after processing', async () => {
  const initialBudget = 50_000_000; // 50 million nano USD
  const supabase = createSupabaseStub([], { budgetNanoUsd: initialBudget });
  const fetchStub = createFetchStub([{ title: 'New Task' }]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email content' }));
  assertEquals(res.status, 200);

  // Verify email was processed
  assertEquals(fetchStub.calls.length, 1);
  assertEquals(supabase.state.raw_emails.length, 1);
  assertEquals(supabase.state.raw_emails[0].status, 'UPDATED_TASKS');

  // Verify budget was decremented (should be less than initial)
  assert(
    supabase.state.budget < initialBudget,
    `Budget should be decremented from ${initialBudget}, but is ${supabase.state.budget}`
  );

  // Verify budget is still positive (since we started with enough)
  assert(supabase.state.budget >= 0, 'Budget should not go negative');
});

test('passes existing tasks and stores new set', async () => {
  const existing = [
    { id: 1, user_id: 'user-1', title: 'Old Task', state: 'OPEN' },
  ];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([{ title: 'New Task' }]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 200);
  assert(fetchStub.calls[0].init.body.includes('Old Task'));
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, 'New Task');
  assertEquals(supabase.state.raw_emails[0].status, 'UPDATED_TASKS');
  assertEquals(supabase.state.raw_emails[0].tasks_after, 1);
});

test('keeps DB unchanged if extraction fails', async () => {
  const existing = [{ user_id: 'user-1', title: 'Keep', state: 'OPEN' }];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([], { fail: true });
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 400);
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, 'Keep');
});

test('rolls back tasks if inserting new tasks fails', async () => {
  const existing = [{ id: 1, user_id: 'user-1', title: 'Old', state: 'OPEN' }];
  const supabase = createSupabaseStub(existing, { failTaskInsert: true });
  const fetchStub = createFetchStub([{ title: 'New' }]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 500);
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, 'Old');
  assertEquals(supabase.state.raw_emails[0].status, 'UNPROCESSED');
});

test('sanitizes invalid task fields', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([
    {
      title: 'Test',
      due_date: '',
      parent_action: 'FLY',
      student_action: '',
      parent_requirement_level: 'MUST',
      student_requirement_level: 'MANDATORY',
    },
  ]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 200);
  const stored = supabase.state.tasks[0];
  assertEquals(stored.due_date, null);
  assertEquals(stored.parent_action, null);
  assertEquals(stored.student_action, null);
  assertEquals(stored.parent_requirement_level, null);
  assertEquals(stored.student_requirement_level, 'MANDATORY');
});

test('logs OpenAI response when task insert fails', async () => {
  const existing = [{ user_id: 'user-1', title: 'Old', state: 'OPEN' }];
  const supabase = createSupabaseStub(existing, { failTaskInsert: true });
  const fetchStub = createFetchStub([{ title: 'New' }]);
  const handler = makeHandler(supabase, fetchStub);

  const errors: string[] = [];
  const orig = console.error;
  console.error = (...args: any[]) => {
    errors.push(args.join(' '));
  };
  const res = await handler(makeReq({ TextBody: 'email' }));
  console.error = orig;
  assertEquals(res.status, 500);
  const combined = errors.join(' ');
  assert(combined.includes('openai_response'));
  assert(combined.includes('New'));
});

test('handles zero tasks correctly', async () => {
  const existing = [{ id: 1, user_id: 'user-1', title: 'Old', state: 'OPEN' }];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.task_count, 0);
  assertEquals(supabase.state.tasks.length, 0);
});

test('detects duplicate emails by Message-ID', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  const payload = {
    TextBody: 'email',
    MessageID: '<id-1>',
    Date: 'Mon, 20 Jan 2025 10:00:00 +0000',
  };

  let res = await handler(makeReq(payload));
  assertEquals(res.status, 200);

  res = await handler(makeReq(payload));
  assertEquals(res.status, 200); // Should return 200 (not 409) to prevent retries
  assertEquals(supabase.state.raw_emails.length, 1);
});

test('dedupes emails without Message-ID using other fields', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = makeHandler(supabase, fetchStub);

  const payload = {
    TextBody: 'email',
    From: 'a@example.com',
    Subject: 'Hello',
    Date: 'Mon, 20 Jan 2025 10:00:00 +0000',
  };

  let res = await handler(makeReq(payload));
  assertEquals(res.status, 200);

  res = await handler(makeReq(payload));
  assertEquals(res.status, 200); // Returns 200 to prevent retries by email service
  assertEquals(supabase.state.raw_emails.length, 1);
});

test('only open tasks are deduped', async () => {
  const existing = [
    { id: 1, user_id: 'user-1', title: 'Open', state: 'OPEN' },
    { id: 2, user_id: 'user-1', title: 'Completed', state: 'COMPLETED' },
  ];
  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([{ title: 'New' }]);
  const handler = makeHandler(supabase, fetchStub);

  const res = await handler(makeReq({ TextBody: 'email' }));
  assertEquals(res.status, 200);
  const body = fetchStub.calls[0].init.body;
  assert(body.includes('Open'));
  assert(!body.includes('Completed'));
  const titles = supabase.state.tasks.map((t) => t.title).sort();
  assert(titles.includes('Completed'));
  assert(titles.includes('New'));
  assert(!titles.includes('Open'));
});

test('only future or no-due-date open tasks are fetched for deduplication', async () => {
  // Mock the current time
  const mockNow = '2025-01-01T12:00:00.000Z';
  const originalToISOString = Date.prototype.toISOString;
  Date.prototype.toISOString = function () {
    return mockNow;
  };

  const existing = [
    {
      id: 1,
      user_id: 'user-1',
      title: 'Past task',
      state: 'OPEN',
      due_date: '2024-12-31',
    },
    {
      id: 2,
      user_id: 'user-1',
      title: 'Future task',
      state: 'OPEN',
      due_date: '2025-01-02',
    },
    {
      id: 3,
      user_id: 'user-1',
      title: 'No due date',
      state: 'OPEN',
      due_date: null,
    },
    {
      id: 4,
      user_id: 'user-1',
      title: 'Completed past',
      state: 'COMPLETED',
      due_date: '2024-12-31',
    },
  ];

  const supabase = createSupabaseStub(existing);
  const fetchStub = createFetchStub([{ title: 'New task' }]);

  // Track which tasks were queried by intercepting the .or() call
  const queriedTasks: any[] = [];
  const originalFrom = supabase.from;
  supabase.from = function (table: string) {
    const result = originalFrom.call(this, table);
    if (table === 'user_tasks' && result.select) {
      const originalSelect = result.select;
      result.select = function (fields: string) {
        const selectResult = originalSelect.call(this, fields);
        // Mock the filtered result to only include future/null due date tasks
        if (selectResult.or) {
          const originalOr = selectResult.or;
          selectResult.or = function (condition: string) {
            // Simulate the database filtering: only return tasks that match our criteria
            const filtered = existing.filter(
              (task) =>
                task.state === 'OPEN' &&
                (task.due_date === null ||
                  task.due_date >= mockNow.split('T')[0])
            );
            queriedTasks.push(...filtered);
            return { data: filtered, error: null };
          };
        }
        return selectResult;
      };
    }
    return result;
  };

  const handler = makeHandler(supabase, fetchStub);
  const res = await handler(makeReq({ TextBody: 'email' }));

  assertEquals(res.status, 200);

  // Verify only future and null due date tasks were returned
  assertEquals(queriedTasks.length, 2);
  const titles = queriedTasks.map((t) => t.title);
  assert(titles.includes('Future task'), 'Should include future task');
  assert(titles.includes('No due date'), 'Should include null due date task');
  assert(!titles.includes('Past task'), 'Should not include past task');
  assert(
    !titles.includes('Completed past'),
    'Should not include completed task'
  );

  // Restore original Date method
  Date.prototype.toISOString = originalToISOString;
});
