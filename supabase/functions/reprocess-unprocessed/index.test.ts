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

test('processes UNPROCESSED raw emails', async () => {
  const rawEmails = [
    {
      id: 1,
      user_id: 'user-1',
      text_body: 'email',
      html_body: null,
      status: 'UNPROCESSED',
    },
  ];
  const tasks = [{ id: 1, user_id: 'user-1', title: 'Old', state: 'OPEN' }];
  const supabase = createSupabaseStub(tasks);
  // Set up raw emails manually since the shared stub doesn't accept them as parameter
  supabase.state.raw_emails = rawEmails;
  const fetchStub = createFetchStub([{ title: 'New' }]);
  const handler = createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: 'test',
    serviceRoleKey: 'svc',
  });

  const res = await handler(
    new Request('http://localhost', {
      method: 'POST',
      headers: { authorization: 'Bearer svc' },
    })
  );
  assertEquals(res.status, 200);
  assertEquals(supabase.state.tasks.length, 1);
  assertEquals(supabase.state.tasks[0].title, 'New');
  assertEquals(supabase.state.raw_emails[0].status, 'UPDATED_TASKS');
  const body = await res.json();
  assertEquals(body.processed, 1);
});

test('requires service role key', async () => {
  const supabase = createSupabaseStub();
  const fetchStub = createFetchStub([]);
  const handler = createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: 'test',
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', { method: 'POST' })
  );
  assertEquals(res.status, 401);
});

test('skips when budget depleted', async () => {
  const rawEmails = [
    {
      id: 1,
      user_id: 'user-1',
      text_body: 'email',
      html_body: null,
      status: 'UNPROCESSED',
    },
  ];
  const supabase = createSupabaseStub([], { budgetNanoUsd: 0 });
  supabase.state.raw_emails = rawEmails;
  const fetchStub = createFetchStub([{ title: 'New' }]);
  const handler = createHandler({
    supabase,
    fetch: fetchStub,
    openAiApiKey: 'test',
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', {
      method: 'POST',
      headers: { authorization: 'Bearer svc' },
    })
  );
  assertEquals(res.status, 200);
  assertEquals(fetchStub.calls.length, 0);
  assertEquals(supabase.state.raw_emails[0].status, 'UNPROCESSED');
  const body = await res.json();
  assertEquals(body.processed, 0);
});
