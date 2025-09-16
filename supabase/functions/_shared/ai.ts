export interface AIPromptConfig {
  id: number;
  is_active: boolean;
  model: string;
  prompt: string;
  temperature: number | null;
  top_p: number | null;
  seed: number | null;
  input_cost_nano_per_token: number;
  output_cost_nano_per_token: number;
  cost_currency: string;
}

export interface AIInvocation {
  id: number;
  config_id: number;
  user_id: string;
  email_id?: string | null;
  request_tokens: number;
  response_tokens: number;
  input_cost_nano: number;
  output_cost_nano: number;
  total_cost_nano: number;
  latency_ms: number | null;
  created_at: string;
}

export async function fetchActivePromptConfig(
  supabase: any
): Promise<AIPromptConfig | null> {
  const { data, error } = await supabase
    .from('ai_prompt_configs')
    .select('*')
    .eq('is_active', true)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error || !data) return null;
  return data as AIPromptConfig;
}

export interface RunModelDeps {
  supabase: any;
  fetch: typeof fetch;
  openAiApiKey: string;
  userId: string;
  emailId?: string;
  userContent: string;
  responseFormat?: any;
}

export async function runModel({
  supabase,
  fetch,
  openAiApiKey,
  userId,
  emailId,
  userContent,
  responseFormat,
}: RunModelDeps): Promise<{
  content: string;
  aiInvocation: AIInvocation;
}> {
  const config = await fetchActivePromptConfig(supabase);
  if (!config) throw new Error('No active prompt config');

  const body: any = {
    model: config.model,
    messages: [
      { role: 'system', content: config.prompt },
      { role: 'user', content: userContent },
    ],
  };
  if (config.temperature !== null && config.temperature !== undefined)
    body.temperature = config.temperature;
  if (config.top_p !== null && config.top_p !== undefined)
    body.top_p = config.top_p;
  if (config.seed !== null && config.seed !== undefined)
    body.seed = config.seed;
  if (responseFormat) body.response_format = responseFormat;

  const start = Date.now();
  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${openAiApiKey}`,
    },
    body: JSON.stringify(body),
  });
  const latency = Date.now() - start;

  if (!resp.ok) throw new Error(await resp.text());
  const data = await resp.json();
  const promptTokens = data?.usage?.prompt_tokens ?? 0;
  const completionTokens = data?.usage?.completion_tokens ?? 0;
  const inputCost = promptTokens * config.input_cost_nano_per_token;
  const outputCost = completionTokens * config.output_cost_nano_per_token;

  const { data: aiInvocation, error: insertError } = await supabase
    .from('ai_invocations')
    .insert({
      config_id: config.id,
      user_id: userId,
      email_id: emailId ?? null,
      request_tokens: promptTokens,
      response_tokens: completionTokens,
      input_cost_nano: inputCost,
      output_cost_nano: outputCost,
      latency_ms: latency,
    })
    .select()
    .single();
  if (insertError || !aiInvocation)
    throw new Error(insertError?.message || 'Failed to log invocation');

  const content = data.choices?.[0]?.message?.content ?? '';
  return { content, aiInvocation: aiInvocation as AIInvocation };
}
