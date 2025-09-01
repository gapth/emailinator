function assertEquals(actual: unknown, expected: unknown, msg = '') {
  if (actual !== expected)
    throw new Error(msg || `Expected ${expected}, got ${actual}`);
}

import { createHandler } from './index.ts';
import { test } from 'node:test';

function createSupabaseStub(initial = 0) {
  const state = { budget: initial };
  return {
    state,
    from(table: string) {
      if (table !== 'processing_budgets') throw new Error('unknown table');
      return {
        select() {
          const builder: any = {
            eq(_f: string, _v: any) {
              return builder;
            },
            single() {
              if (state.budget === undefined)
                return { data: null, error: { code: 'PGRST116' } };
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
      };
    },
  };
}

test('requires service role key', async () => {
  const supabase = createSupabaseStub();
  const handler = createHandler({
    supabase,
    depositNanoUsd: 10,
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', { method: 'POST' })
  );
  assertEquals(res.status, 401);
});

test('deposits budget', async () => {
  const supabase = createSupabaseStub(5);
  const handler = createHandler({
    supabase,
    depositNanoUsd: 10,
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', {
      method: 'POST',
      headers: { authorization: 'Bearer svc' },
      body: JSON.stringify({ user_id: 'u1' }),
    })
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.new_balance, 15);
  assertEquals(supabase.state.budget, 15);
});
