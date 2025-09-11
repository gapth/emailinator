function assertEquals(actual: unknown, expected: unknown, msg = '') {
  if (actual !== expected)
    throw new Error(msg || `Expected ${expected}, got ${actual}`);
}

import { createHandler } from './index.ts';
import { test } from 'node:test';

function createSupabaseStub(initialBudgets: Record<string, number> = {}) {
  const state = { budgets: initialBudgets };
  return {
    state,
    auth: {
      admin: {
        listUsers() {
          const users = Object.keys(state.budgets).map((id) => ({ id }));
          return {
            data: { users },
            error: null,
          };
        },
      },
    },
    rpc(
      functionName: string,
      params: { p_user_id: string; p_amount: number; p_max_budget: number }
    ) {
      if (functionName !== 'increment_processing_budget') {
        throw new Error(`Unknown function: ${functionName}`);
      }

      const { p_user_id, p_amount, p_max_budget } = params;
      const current = state.budgets[p_user_id] || 0;
      const newBalance = Math.min(current + p_amount, p_max_budget);
      state.budgets[p_user_id] = newBalance;

      return { data: newBalance, error: null };
    },
  };
}

test('requires service role key', async () => {
  const supabase = createSupabaseStub();
  const handler = createHandler({
    supabase,
    depositNanoUsd: 10,
    maxAccruedNanoUsd: 100,
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', { method: 'POST' })
  );
  assertEquals(res.status, 401);
});

test('deposits budget for all users', async () => {
  const supabase = createSupabaseStub({ user1: 5, user2: 0 });
  const handler = createHandler({
    supabase,
    depositNanoUsd: 10,
    maxAccruedNanoUsd: 100,
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', {
      method: 'POST',
      headers: { authorization: 'Bearer svc' },
    })
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.deposited_amount, 10);
  assertEquals(body.max_budget, 100);
  assertEquals(body.users_processed, 2);
  assertEquals(supabase.state.budgets['user1'], 15);
  assertEquals(supabase.state.budgets['user2'], 10);
});

test('respects budget cap', async () => {
  const supabase = createSupabaseStub({ user1: 95 });
  const handler = createHandler({
    supabase,
    depositNanoUsd: 10,
    maxAccruedNanoUsd: 100,
    serviceRoleKey: 'svc',
  });
  const res = await handler(
    new Request('http://localhost', {
      method: 'POST',
      headers: { authorization: 'Bearer svc' },
    })
  );
  assertEquals(res.status, 200);
  assertEquals(supabase.state.budgets['user1'], 100); // Capped at max
});
