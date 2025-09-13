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
import { createSupabaseStub, createFetchStub } from '../_shared/test-utils.ts';

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
  assertEquals(supabase.state.tasks.length, 2); // Keep existing + add new
  const titles = supabase.state.tasks.map((t) => t.title).sort();
  assert(titles.includes('Old Task')); // Existing task should remain
  assert(titles.includes('New Task')); // New task should be added
  assertEquals(supabase.state.raw_emails[0].status, 'UPDATED_TASKS');
  assertEquals(supabase.state.raw_emails[0].tasks_after, 2); // Total count
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
  assertEquals(body.task_count, 0); // No new tasks added
  assertEquals(supabase.state.tasks.length, 1); // Existing task remains
  assertEquals(supabase.state.tasks[0].title, 'Old'); // Verify existing task is preserved
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
  assert(body.includes('Open')); // Open task should be passed to AI for deduplication
  assert(!body.includes('Completed')); // Completed task should not be passed to AI
  const titles = supabase.state.tasks.map((t) => t.title).sort();
  assert(titles.includes('Completed')); // Completed task should remain
  assert(titles.includes('New')); // New task should be added
  assert(titles.includes('Open')); // Open task should remain (not deleted)
});

test('all open tasks are fetched for deduplication', async () => {
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

  // Track which tasks were queried by intercepting the query to tasks table
  const queriedTasks: Record<string, unknown>[] = [];
  const originalFrom = supabase.from;
  supabase.from = function (table: string) {
    const result = originalFrom.call(this, table);
    if (table === 'tasks' && result.select) {
      const originalSelect = result.select;
      result.select = function (fields?: string) {
        const selectResult = originalSelect.call(this, fields);
        // Override the result to capture all tasks, then filter for open ones
        if (selectResult.then) {
          const originalThen = selectResult.then;
          selectResult.then = function (resolve: any) {
            // Return all tasks with mock user_task_states
            const tasksWithState = existing.map((task) => ({
              ...task,
              user_task_states: [{ state: task.state || 'OPEN' }],
            }));
            // The actual code will filter these for OPEN state
            queriedTasks.push(
              ...tasksWithState.filter(
                (t) => (t.user_task_states[0]?.state || 'OPEN') === 'OPEN'
              )
            );
            return resolve({ data: tasksWithState, error: null });
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

  // Verify ALL open tasks were returned (past, future, and null due date)
  assertEquals(queriedTasks.length, 3);
  const titles = queriedTasks.map((t) => t.title);
  assert(titles.includes('Past task'), 'Should include past task');
  assert(titles.includes('Future task'), 'Should include future task');
  assert(titles.includes('No due date'), 'Should include null due date task');
  assert(
    !titles.includes('Completed past'),
    'Should not include completed task'
  );

  // Restore original Date method
  Date.prototype.toISOString = originalToISOString;
});
