// Shared test utilities for Supabase Edge Functions
// deno-lint-ignore-file no-explicit-any

export interface SupabaseStubState {
  raw_emails: any[];
  tasks: any[];
  budget: number;
  aliases: any[];
  forwarding_verifications: any[];
}

export interface SupabaseStubOptions {
  failTaskInsert?: boolean;
  budgetNanoUsd?: number;
}

// Supabase stub factory
export function createSupabaseStub(
  initialTasks: any[] = [],
  opts: SupabaseStubOptions = {}
) {
  const state: SupabaseStubState = {
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
              _orderBy: null as { field: string; ascending: boolean } | null,
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
              order(field: string, opts: { ascending: boolean }) {
                this._orderBy = { field, ascending: opts.ascending };
                return builder;
              },
              then(resolve: any) {
                let data = state.raw_emails.filter((r) =>
                  builder._filters.every((f: any) => f(r))
                );

                // Apply ordering if specified
                if (builder._orderBy) {
                  const { field, ascending } = builder._orderBy;
                  data = data.sort((a, b) => {
                    const aVal = a[field];
                    const bVal = b[field];
                    if (aVal < bVal) return ascending ? -1 : 1;
                    if (aVal > bVal) return ascending ? 1 : -1;
                    return 0;
                  });
                }

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
          select(fields?: string) {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                builder._filters.push((r: any) => r[field] === value);
                return builder;
              },
              or(condition: string, opts?: { foreignTable?: string }) {
                // Handle the specific OR condition for open tasks:
                // 'state.is.null,state.eq.OPEN' with foreignTable: 'user_task_states'
                if (
                  opts?.foreignTable === 'user_task_states' &&
                  condition.includes('state.is.null') &&
                  condition.includes('state.eq.OPEN')
                ) {
                  builder._filters.push((r: any) => {
                    const taskState =
                      r.user_task_states?.[0]?.state || r.state || 'OPEN';
                    return taskState === 'OPEN';
                  });
                }
                return builder;
              },
              then(resolve: any) {
                let data = state.tasks.filter((t) =>
                  builder._filters.every((f: any) => f(t))
                );

                // Simulate the join with user_task_states
                if (fields && fields.includes('user_task_states')) {
                  data = data.map((task) => ({
                    ...task,
                    user_task_states: [{ state: task.state || 'OPEN' }],
                  }));
                }

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
            if (Array.isArray(rows)) {
              state.tasks.push(...rows);
            } else {
              state.tasks.push(rows);
            }
            return { error: null };
          },
        };
      }
      if (table === 'processing_budgets') {
        return {
          select() {
            const builder: any = {
              eq(_field: string, _value: any) {
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
            return {
              select() {
                return {
                  single() {
                    return { data: row, error: null };
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
      if (table === 'ai_prompt_config') {
        return {
          select() {
            const builder: any = {
              _filters: [] as ((r: any) => boolean)[],
              eq(field: string, value: any) {
                this._filters.push((r: any) => r[field] === value);
                return builder;
              },
              order(_field: string, _opts: any) {
                return builder;
              },
              limit(_count: number) {
                return builder;
              },
              maybeSingle() {
                // Return a default config for testing
                return {
                  data: {
                    id: 1,
                    system_prompt: 'Test system prompt',
                    model: 'gpt-4',
                    temperature: 0.1,
                    max_tokens: 2000,
                    input_cost_nano_per_token: 10,
                    output_cost_nano_per_token: 30,
                  },
                  error: null,
                };
              },
            };
            return builder;
          },
        };
      }
      if (table === 'ai_invocations') {
        return {
          insert(row: any) {
            const id = Date.now(); // Simple ID generation for tests
            // Calculate total_cost_nano from input_cost_nano and output_cost_nano
            const totalCostNano =
              (row.input_cost_nano || 0) + (row.output_cost_nano || 0);
            const fullRow = {
              id,
              ...row,
              total_cost_nano: totalCostNano,
            };
            return {
              select() {
                return {
                  single() {
                    return { data: fullRow, error: null };
                  },
                };
              },
            };
          },
        };
      }
      throw new Error(`unknown table: ${table}`);
    },
    rpc(functionName: string, params: Record<string, unknown>) {
      if (functionName === 'decrement_processing_budget') {
        // Simulate successful budget decrement
        const { p_amount } = params;
        if (typeof p_amount !== 'number' || isNaN(p_amount)) {
          return { data: null, error: { message: 'Invalid amount' } };
        }
        const newRemaining = state.budget - p_amount;
        if (newRemaining < 0) {
          return { data: null, error: { message: 'Insufficient budget' } };
        }
        state.budget = newRemaining;
        return { data: newRemaining, error: null };
      }
      throw new Error(`unknown RPC function: ${functionName}`);
    },
  };
}

export function createFetchStub(
  returnTasks: any[],
  opts: { fail?: boolean } = {}
) {
  const calls: any[] = [];
  const fetchFn = (_url: string, init: any) => {
    calls.push({ url: _url, init });
    if (opts.fail) {
      return Promise.resolve({
        ok: false,
        text: () => Promise.resolve('failure'),
      });
    }
    return Promise.resolve({
      ok: true,
      json() {
        return Promise.resolve({
          choices: [
            { message: { content: JSON.stringify({ tasks: returnTasks }) } },
          ],
          usage: { prompt_tokens: 1, completion_tokens: returnTasks.length },
        });
      },
    });
  };
  (fetchFn as any).calls = calls;
  return fetchFn as typeof fetch & { calls: any[] };
}
