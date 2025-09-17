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
  Headers?: Array<{ Name?: string; Value?: string }>; // Postmark top-level headers

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
  // Extract a lowercased email address from a header value like
  // '"Name" <user@example.com>' or 'user@example.com'
  function extractEmailAddress(
    input: string | null | undefined
  ): string | null {
    if (!input) return null;
    const match = input.match(/<([^>]+)>/);
    const email = (match ? match[1] : input).trim().toLowerCase();
    return email || null;
  }

  function domainFromEmail(addr: string | null | undefined): string | null {
    const email = extractEmailAddress(addr ?? null);
    if (!email) return null;
    const atIdx = email.lastIndexOf('@');
    if (atIdx === -1) return null;
    const host = email.slice(atIdx + 1).toLowerCase();
    return host || null;
  }

  // Very small helper to approximate eTLD+1 by taking the last two labels.
  // This is not perfect for multi-level TLDs, but is acceptable for common cases.
  function registrableDomain(host: string | null | undefined): string | null {
    if (!host) return null;
    const clean = host.replace(/^www\./i, '').toLowerCase();
    const parts = clean.split('.').filter(Boolean);
    if (parts.length <= 2) return parts.join('.') || null;
    return parts.slice(-2).join('.');
  }

  function getHeaderMap(payload: any): Map<string, string> {
    const map = new Map<string, string>();
    // Prefer Postmark top-level Headers array if present
    const top = Array.isArray(payload?.Headers) ? payload.Headers : [];
    const pm = payload?.ProviderMeta;
    const pmHeaders = Array.isArray(pm?.Headers) ? pm.Headers : [];
    for (const h of [...top, ...pmHeaders]) {
      const name = String(h?.Name ?? h?.name ?? '').toLowerCase();
      const value = String(h?.Value ?? h?.value ?? '');
      if (name) map.set(name, value);
    }
    return map;
  }

  function getHeaderValues(payload: any, nameLower: string): string[] {
    const out: string[] = [];
    const top = Array.isArray(payload?.Headers) ? payload.Headers : [];
    for (const h of top) {
      const n = String(h?.Name ?? h?.name ?? '').toLowerCase();
      if (n === nameLower) out.push(String(h?.Value ?? h?.value ?? ''));
    }
    const pm = payload?.ProviderMeta;
    const pmHeaders = Array.isArray(pm?.Headers) ? pm.Headers : [];
    for (const h of pmHeaders) {
      const n = String(h?.Name ?? h?.name ?? '').toLowerCase();
      if (n === nameLower) out.push(String(h?.Value ?? h?.value ?? ''));
    }
    return out;
  }

  function extractListIdDomain(listIdRaw: string | undefined): string | null {
    if (!listIdRaw) return null;
    const inside = listIdRaw.match(/<([^>]+)>/);
    const token = (inside ? inside[1] : listIdRaw).trim();
    const domMatch = token.match(/([A-Za-z0-9.-]+\.[A-Za-z]{2,})/);
    return domMatch ? domMatch[1].toLowerCase() : null;
  }

  function extractDkimDomain(
    authResultsList: string[],
    dkimHeaders: string[],
    fromDomain: string | null
  ): string | null {
    const candidates = new Set<string>();
    for (const h of dkimHeaders) {
      const re = /\bd=([^;\s]+)/gi;
      let m: RegExpExecArray | null;
      while ((m = re.exec(h)) !== null) candidates.add(m[1].toLowerCase());
    }
    const passDomains = new Set<string>();
    for (const ar of authResultsList) {
      // Capture domains that appear with dkim=pass and header.i or header.d
      // Examples: 'dkim=pass header.i=@notify.castilleja.org', 'header.d=notify.castilleja.org'
      const lower = ar.toLowerCase();
      const segments = lower.split(/;\s*/);
      for (const seg of segments) {
        if (seg.includes('dkim=pass')) {
          const mI = seg.match(/header\.i=@([^;\s]+)/i);
          if (mI) passDomains.add(mI[1]);
          const mD =
            seg.match(/header\.d=([^;\s]+)/i) || seg.match(/\bd=([^;\s]+)/i);
          if (mD) passDomains.add(mD[1]);
        }
        const mAnyD =
          seg.match(/header\.d=([^;\s]+)/i) || seg.match(/\bd=([^;\s]+)/i);
        if (mAnyD) candidates.add(mAnyD[1]);
        const mAnyI = seg.match(/header\.i=@([^;\s]+)/i);
        if (mAnyI) candidates.add(mAnyI[1]);
      }
    }

    const all = Array.from(candidates);
    if (all.length === 0) return null;

    const fromReg = registrableDomain(fromDomain ?? undefined);
    const espDomains = new Set([
      'mailgun.org',
      'sendgrid.net',
      'amazonses.com',
      'sparkpostmail.com',
      'postmarkapp.com',
      'mandrillapp.com',
      'mailchimp.com',
    ]);

    function score(domain: string): number {
      const reg = registrableDomain(domain) ?? domain;
      let s = 0;
      if (passDomains.has(domain) || passDomains.has(reg)) s += 10;
      if (fromReg && reg === fromReg) s += 20; // DMARC-aligned registrable domain
      // Longer subdomain match of fromDomain gets slight boost
      if (fromDomain && domain.endsWith('.' + fromDomain)) s += 2;
      if (!espDomains.has(reg)) s += 1; // prefer non-ESP
      // Specificity: more labels → slightly higher
      s += Math.max(0, domain.split('.').length - 2) * 0.1;
      return s;
    }

    let best = all[0];
    let bestScore = score(best);
    for (const d of all.slice(1)) {
      const sc = score(d);
      if (sc > bestScore || (sc === bestScore && d.length > best.length)) {
        best = d;
        bestScore = sc;
      }
    }
    return best.toLowerCase();
  }

  function extractUnsubscribeDomain(raw: string | undefined): string | null {
    if (!raw) return null;
    // Prefer an http(s) URL
    const urlMatch =
      raw.match(/<\s*(https?:[^>\s]+)\s*>/i) || raw.match(/\bhttps?:[^,>\s]+/i);
    if (urlMatch) {
      try {
        const u = new URL(urlMatch[1] ?? urlMatch[0]);
        return u.host.toLowerCase();
      } catch {}
    }
    // Fallback: mailto
    const mailtoMatch =
      raw.match(/<\s*mailto:([^>\s]+)\s*>/i) || raw.match(/mailto:([^,>\s]+)/i);
    if (mailtoMatch) {
      const addr = mailtoMatch[1];
      return domainFromEmail(addr);
    }
    return null;
  }

  function toPlatformHint(regDomain: string | null): string | null {
    if (!regDomain) return null;
    const sld = regDomain.split('.')[0];
    return sld || null;
  }

  async function observeSourceInfo(
    supabase: any,
    user_id: string,
    payload: any
  ) {
    try {
      const headers = getHeaderMap(payload);
      const listId = headers.get('list-id') ?? headers.get('listid');
      const listIdDomain = extractListIdDomain(listId);

      const dkimHeaders = getHeaderValues(payload, 'dkim-signature');
      const authResList = [
        ...getHeaderValues(payload, 'authentication-results'),
        ...getHeaderValues(payload, 'authentication-results-original'),
        ...getHeaderValues(payload, 'arc-authentication-results'),
      ];
      const fromDomain = domainFromEmail(payload?.From);
      const dkim_d = extractDkimDomain(authResList, dkimHeaders, fromDomain);

      const returnPath = headers.get('return-path');
      const returnPathDomain = domainFromEmail(returnPath ?? undefined);

      // fromDomain already computed above

      const listUnsub = headers.get('list-unsubscribe');
      const unsubscribeDomain = extractUnsubscribeDomain(listUnsub);

      const candidate =
        dkim_d ||
        listIdDomain ||
        fromDomain ||
        returnPathDomain ||
        unsubscribeDomain;
      const regDomain = registrableDomain(candidate);
      if (!regDomain) return; // Nothing to store

      const platform_hint = toPlatformHint(regDomain);

      // Merge with existing row if present
      const { data: existing, error: selErr } = await supabase
        .from('source_observations')
        .select('*')
        .eq('user_id', user_id)
        .eq('registrable_domain', regDomain)
        .maybeSingle();
      if (selErr) return; // Non-fatal

      if (existing) {
        const updates: Record<string, any> = {
          msg_last_seen: new Date().toISOString(),
          msg_count: (existing.msg_count ?? 0) + 1,
        };
        if (listId && listId !== existing.list_id) updates.list_id = listId;
        if (dkim_d && dkim_d !== existing.dkim_d) updates.dkim_d = dkim_d;
        if (fromDomain && fromDomain !== existing.sender_domain)
          updates.sender_domain = fromDomain;
        if (
          unsubscribeDomain &&
          unsubscribeDomain !== existing.unsubscribe_domain
        )
          updates.unsubscribe_domain = unsubscribeDomain;
        if (platform_hint && platform_hint !== existing.platform_hint)
          updates.platform_hint = platform_hint;

        await supabase
          .from('source_observations')
          .update(updates)
          .eq('id', existing.id);
      } else {
        await supabase.from('source_observations').insert({
          user_id,
          registrable_domain: regDomain,
          list_id: listId ?? null,
          dkim_d: dkim_d ?? null,
          sender_domain: fromDomain ?? returnPathDomain ?? null,
          unsubscribe_domain: unsubscribeDomain ?? null,
          platform_hint: platform_hint ?? null,
          // msg_* fields rely on defaults
        });
      }
    } catch (_) {
      // Do not block processing if observation fails
    }
  }
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
      // Fire-and-forget: observe source info for analytics/attribution
      observeSourceInfo(supabase, user_id, payload);

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
