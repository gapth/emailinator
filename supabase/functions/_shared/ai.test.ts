// Minimal assertion helpers
function assert(cond: boolean, msg = 'Assertion failed') {
  if (!cond) throw new Error(msg);
}
function assertEquals(actual: unknown, expected: unknown, msg = '') {
  if (actual !== expected) {
    throw new Error(msg || `Expected ${expected}, got ${actual}`);
  }
}

import {
  runModel,
  fetchActivePromptConfig,
  AIPromptConfig,
  AIInvocation,
} from './ai.ts';
import { test } from 'node:test';

function createSupabaseStub(config: AIPromptConfig) {
  const state = { invocations: [] as AIInvocation[] };
  return {
    state,
    from(table: string) {
      if (table === 'ai_prompt_config') {
        return {
          select() {
            return {
              eq() {
                return {
                  order() {
                    return {
                      limit() {
                        return {
                          maybeSingle() {
                            return { data: config, error: null };
                          },
                        };
                      },
                    };
                  },
                };
              },
            };
          },
        };
      }
      if (table === 'ai_invocations') {
        return {
          insert(row: any) {
            const inserted: AIInvocation = {
              id: 'inv-1',
              created_at: new Date().toISOString(),
              total_cost_nano: row.input_cost_nano + row.output_cost_nano,
              ...row,
            };
            state.invocations.push(inserted);
            return {
              select() {
                return {
                  single() {
                    return { data: inserted, error: null };
                  },
                };
              },
            };
          },
        };
      }
      throw new Error('Unknown table ' + table);
    },
  };
}

test('runModel returns content and logs invocation', async () => {
  const config: AIPromptConfig = {
    id: 'cfg-1',
    is_active: true,
    model: 'gpt-4',
    prompt: 'You are helpful',
    temperature: null,
    top_p: null,
    seed: null,
    input_cost_nano_per_token: 2,
    output_cost_nano_per_token: 3,
    cost_currency: 'USD',
  };
  const supabase = createSupabaseStub(config);
  let capturedBody: any = null;
  const fakeFetch = async (_url: string, opts: any) => {
    capturedBody = JSON.parse(opts.body);
    return {
      ok: true,
      json: async () => ({
        choices: [{ message: { content: 'hi' } }],
        usage: { prompt_tokens: 5, completion_tokens: 7 },
      }),
    };
  };

  const responseFormat = {
    type: 'json_schema',
    json_schema: { name: 'n', schema: { type: 'object' } },
  };
  const { content, aiInvocation } = await runModel({
    supabase,
    fetch: fakeFetch as any,
    openAiApiKey: 'k',
    userId: 'user-1',
    userContent: 'hello',
    responseFormat,
  });

  assertEquals(content, 'hi');
  assertEquals(aiInvocation.request_tokens, 5);
  assertEquals(aiInvocation.response_tokens, 7);
  assertEquals(aiInvocation.input_cost_nano, 10);
  assertEquals(aiInvocation.output_cost_nano, 21);
  assertEquals(aiInvocation.total_cost_nano, 31);
  assertEquals(supabase.state.invocations.length, 1);
  assertEquals(
    JSON.stringify(capturedBody.response_format),
    JSON.stringify(responseFormat)
  );
});

test('fetchActivePromptConfig returns null when none active', async () => {
  const supabase = {
    from() {
      return {
        select() {
          return {
            eq() {
              return {
                order() {
                  return {
                    limit() {
                      return {
                        maybeSingle() {
                          return { data: null, error: new Error('none') };
                        },
                      };
                    },
                  };
                },
              };
            },
          };
        },
      };
    },
  } as any;
  const config = await fetchActivePromptConfig(supabase);
  assertEquals(config, null);
});
