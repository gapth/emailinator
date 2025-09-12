// deno-lint-ignore-file no-explicit-any
import {
  extractNewTasks,
  addNewTasksAndUpdateEmail,
  chooseEmailText,
  getOpenTasksForDeduplication,
  getUserProcessingBudget,
  decrementProcessingBudget,
} from '../_shared/task-utils.ts';

type InboundPayload = {
  From?: string;
  To?: string;
  Cc?: string;
  Bcc?: string;
  Subject?: string;
  TextBody?: string;
  HtmlBody?: string;
  Date?: string;
  MessageID?: string;
  ProviderMeta?: Record<string, any>;

  // Postmark full address arrays
  ToFull?: Array<{ Email: string; Name: string; MailboxHash: string }>;
  CcFull?: Array<{ Email: string; Name: string; MailboxHash: string }>;
  BccFull?: Array<{ Email: string; Name: string; MailboxHash: string }>;
};

function extractForwardVerificationLink(payload: any): string | null {
  const from = (payload.From ?? payload.from_email ?? '').toLowerCase();
  const subject = (payload.Subject ?? payload.subject ?? '').toLowerCase();
  const text_body = (payload.TextBody ?? payload.text_body ?? '') as string;
  const html_body = (payload.HtmlBody ?? payload.html_body ?? '') as string;
  const body = chooseEmailText({ text_body, html_body }) ?? '';

  let match: RegExpMatchArray | null = null;
  if (
    from.includes('forwarding-noreply@google.com') ||
    subject.includes('gmail forwarding confirmation')
  ) {
    match = body.match(/https:\/\/mail-settings\.google\.com\/mail\/[^\s]+/i);
  }
  if (
    !match &&
    subject.includes('forward') &&
    (subject.includes('confirm') || subject.includes('verification'))
  ) {
    match = body.match(/https?:\/\/[^\s]+/i);
  }
  return match ? match[0] : null;
}

export interface Deps {
  supabase: any;
  fetch: typeof fetch;
  openAiApiKey: string;
  basicUser: string;
  basicPassword: string;
  allowedIps: string[];
  inboundDomain: string;
}

export function createHandler({
  supabase,
  fetch,
  openAiApiKey,
  basicUser,
  basicPassword,
  allowedIps,
  inboundDomain,
}: Deps) {
  return async function handler(req: Request): Promise<Response> {
    if (req.method !== 'POST')
      return new Response('Method Not Allowed', { status: 405 });
    const ipHeader = req.headers.get('x-forwarded-for') ?? '';
    const ip = ipHeader.split(',')[0].trim();
    if (allowedIps.length > 0 && !allowedIps.includes(ip)) {
      return new Response('Unauthorized', { status: 401 });
    }

    const auth = req.headers.get('authorization') ?? '';
    const [scheme, encoded] = auth.split(' ');
    let decoded: string;
    try {
      decoded = atob(encoded ?? '');
    } catch {
      return new Response('Unauthorized', { status: 401 });
    }
    const expected = `${basicUser}:${basicPassword}`;
    if (scheme !== 'Basic' || decoded !== expected) {
      return new Response('Unauthorized', { status: 401 });
    }

    const rawBody = await req.text();

    function extractAlias(data: any): string | null {
      const inboundDomainLower = inboundDomain.toLowerCase();
      const suffix = '@' + inboundDomainLower;
      const candidates: string[] = [];

      if (typeof (data as any).OriginalRecipient === 'string') {
        candidates.push((data as any).OriginalRecipient);
      }
      for (const field of ['ToFull', 'CcFull', 'BccFull'] as const) {
        const arr = (data as any)[field];
        if (Array.isArray(arr)) {
          for (const item of arr) {
            if (item?.Email) candidates.push(item.Email);
          }
        }
      }
      for (const field of ['To', 'Cc', 'Bcc'] as const) {
        const val = (data as any)[field];
        if (typeof val === 'string') {
          const match = val.match(/<([^>]+)>/);
          candidates.push(match ? match[1] : val);
        }
      }

      for (const email of candidates) {
        const lower = email.toLowerCase();
        if (lower.endsWith(suffix)) return lower;
      }
      return null;
    }

    try {
      const payload = JSON.parse(rawBody) as InboundPayload;

      const alias = extractAlias(payload);
      console.info(`[inbound-email] Alias: ${alias}`);
      if (!alias) return new Response('Unknown alias', { status: 404 });
      const { data: aliasRow, error: aliasError } = await supabase
        .from('email_aliases')
        .select('user_id')
        .eq('alias', alias)
        .eq('active', true)
        .maybeSingle();

      if (aliasError || !aliasRow) {
        console.warn(
          `[inbound-email] Alias lookup failed for ${alias}: ${aliasError?.message}`
        );
        return new Response('Unknown alias', { status: 404 });
      }

      const user_id = aliasRow.user_id;

      const verificationLink = extractForwardVerificationLink(payload);
      if (verificationLink) {
        await supabase.from('forwarding_verifications').insert({
          user_id,
          alias,
          from_email: payload.From ?? null,
          subject: payload.Subject ?? null,
          verification_link: verificationLink,
        });
        console.info(
          `[inbound-email] Forwarding verification captured: ${verificationLink}`
        );
        return new Response('Forwarding verification captured', {
          status: 200,
        });
      }

      const sentAt = payload.Date ? new Date(payload.Date).toISOString() : null;
      const messageId = payload.MessageID ?? null;

      if (messageId) {
        const { data: existingEmail, error: dupError } = await supabase
          .from('raw_emails')
          .select('id')
          .eq('message_id', messageId);
        if (dupError) return new Response(dupError.message, { status: 500 });
        if (Array.isArray(existingEmail) && existingEmail.length > 0) {
          // Duplicate detected by Message-ID. Return 200 OK (not 409) so the inbound
          // email service (e.g. Postmark) does NOT retry delivering this message.
          // We have already processed (or intentionally stored) the original email.
          return new Response('Duplicate Message-ID (already processed)', {
            status: 200,
          });
        }
      } else {
        // No Message-ID, fall back to deduplication by From/To/Subject/SentAt.
        // This is less reliable, but better than nothing.
        // Also return 200 OK on duplicate so the inbound
        // email service (e.g. Postmark) will NOT retry later.
        console.warn(
          `[inbound-email] No Message-ID header present in email from ${payload.From} to ${payload.To} with subject "${payload.Subject}"`
        );
        const query = supabase.from('raw_emails').select('id');
        const fromEmail = payload.From ?? null;
        const toEmail = payload.To ?? null;
        const subject = payload.Subject ?? null;
        if (fromEmail !== null) query.eq('from_email', fromEmail);
        else query.is('from_email', null);
        if (toEmail !== null) query.eq('to_email', toEmail);
        else query.is('to_email', null);
        if (subject !== null) query.eq('subject', subject);
        else query.is('subject', null);
        if (sentAt !== null) query.eq('sent_at', sentAt);
        else query.is('sent_at', null);
        const { data: existingEmail, error: dupError } = await query;
        if (dupError) return new Response(dupError.message, { status: 500 });
        if (Array.isArray(existingEmail) && existingEmail.length > 0) {
          return new Response('Duplicate Message-ID (already processed)', {
            status: 200,
          });
        }
      }

      const emailText = chooseEmailText(payload);
      console.info(
        `[inbound-email] user=${user_id} email_text_length=${emailText.length}`
      );

      const { tasks: existingForAi, error: existingError } =
        await getOpenTasksForDeduplication(supabase, user_id);
      if (existingError) return new Response(existingError, { status: 500 });

      const existingCount = existingForAi.length;
      console.info(
        `[inbound-email] user=${user_id} existing_tasks_for_dedupe=${existingCount}`
      );

      const { budget: remainingBudget, error: budgetError } =
        await getUserProcessingBudget(supabase, user_id);
      const actualRemainingBudget = budgetError ? 0 : remainingBudget;

      if (actualRemainingBudget <= 0) {
        const { error: rawError } = await supabase.from('raw_emails').insert({
          user_id,
          from_email: payload.From ?? null,
          to_email: payload.To ?? null,
          subject: payload.Subject ?? null,
          text_body: payload.TextBody ?? null,
          html_body: payload.HtmlBody ?? null,
          provider_meta: payload.ProviderMeta ?? {},
          sent_at: sentAt,
          message_id: messageId,
          tasks_before: existingCount,
          tasks_after: existingCount,
          status: 'UNPROCESSED',
        });
        if (rawError) return new Response(rawError.message, { status: 500 });
        return new Response(JSON.stringify({ task_count: 0 }), {
          headers: { 'content-type': 'application/json' },
          status: 200,
        });
      }
      // Store raw email first to get its ID for linking with ai_invocations
      const { data: rawData, error: rawError } = await supabase
        .from('raw_emails')
        .insert({
          user_id,
          from_email: payload.From ?? null,
          to_email: payload.To ?? null,
          subject: payload.Subject ?? null,
          text_body: payload.TextBody ?? null,
          html_body: payload.HtmlBody ?? null,
          provider_meta: payload.ProviderMeta ?? {},
          sent_at: sentAt,
          message_id: messageId,
          tasks_before: existingCount,
          tasks_after: existingCount,
          status: 'UNPROCESSED',
        })
        .select('id')
        .single();

      if (rawError) return new Response(rawError.message, { status: 500 });

      const {
        tasks,
        promptTokens,
        completionTokens,
        totalCostNano,
        rawContent,
      } = await extractNewTasks(
        supabase,
        fetch,
        openAiApiKey,
        emailText,
        existingForAi,
        user_id,
        rawData.id
      );
      console.info(`[inbound-email] user=${user_id} new_tasks=${tasks.length}`);

      const applyResult = await addNewTasksAndUpdateEmail({
        supabase,
        userId: user_id,
        rawEmailId: rawData.id,
        newTasks: tasks,
        existingTasksCount: existingCount,
        _promptTokens: promptTokens,
        _completionTokens: completionTokens,
        rawContent,
        logPrefix: 'inbound-email',
      });
      if (!applyResult.success)
        return new Response(applyResult.error, { status: 500 });

      // Atomically decrement the remaining budget using database function
      const { error: budgetUpdateError } = await decrementProcessingBudget(
        supabase,
        user_id,
        totalCostNano,
        'inbound-email'
      );

      if (budgetUpdateError) {
        console.error(
          `[inbound-email] Budget update error: ${budgetUpdateError}`
        );
        return new Response(budgetUpdateError, { status: 500 });
      }

      return new Response(
        JSON.stringify({ task_count: applyResult.taskCount }),
        {
          headers: { 'content-type': 'application/json' },
          status: 200,
        }
      );
    } catch (e) {
      return new Response(`Bad Request: ${e}`, { status: 400 });
    }
  };
}

if (import.meta.main) {
  const { createClient } = await import('jsr:@supabase/supabase-js@2');
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!;
  const POSTMARK_BASIC_USER = Deno.env.get('POSTMARK_BASIC_USER')!;
  const POSTMARK_BASIC_PASSWORD = Deno.env.get('POSTMARK_BASIC_PASSWORD')!;
  const INBOUND_EMAIL_DOMAIN = Deno.env.get('INBOUND_EMAIL_DOMAIN')!;
  const POSTMARK_ALLOWED_IPS = (Deno.env.get('POSTMARK_ALLOWED_IPS') ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  const handler = createHandler({
    supabase,
    fetch,
    openAiApiKey: OPENAI_API_KEY,
    basicUser: POSTMARK_BASIC_USER,
    basicPassword: POSTMARK_BASIC_PASSWORD,
    allowedIps: POSTMARK_ALLOWED_IPS,
    inboundDomain: INBOUND_EMAIL_DOMAIN,
  });
  Deno.serve(handler);
}
