// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // server-side only
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

type InboundPayload = {
  user_id?: string;              // UUID of auth.users (preferred)
  from_email?: string;
  to_email?: string;
  subject?: string;
  text_body?: string;
  html_body?: string;
  provider_meta?: Record<string, any>;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  // Simple shared-secret auth (set this in your provider)
  const secret = req.headers.get("x-emailinator-secret");
  if (!secret || secret !== Deno.env.get("EMAILINATOR_INBOUND_SECRET")) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const payload = await req.json() as InboundPayload;

    // Derive user_id if you encode it in the "to" local part: u_<uuid>@in.emailinator.app
    let user_id = payload.user_id;
    if (!user_id && payload.to_email) {
      const local = payload.to_email.split("@")[0];
      if (local.startsWith("u_")) user_id = local.slice(2);
    }
    if (!user_id) return new Response("Missing user_id", { status: 400 });

    const { error } = await supabase.from("raw_emails").insert({
      user_id,
      from_email: payload.from_email ?? null,
      to_email: payload.to_email ?? null,
      subject: payload.subject ?? null,
      text_body: payload.text_body ?? null,
      html_body: payload.html_body ?? null,
      provider_meta: payload.provider_meta ?? {},
    });

    if (error) return new Response(error.message, { status: 500 });

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "content-type": "application/json" },
      status: 200
    });
  } catch (e) {
    return new Response(`Bad Request: ${e}`, { status: 400 });
  }
});
