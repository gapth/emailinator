// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // server-side only
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

type InboundPayload = {
  from_email?: string;
  to_email?: string;
  subject?: string;
  text_body?: string;
  html_body?: string;
  provider_meta?: Record<string, any>;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  // Authenticate using the caller's Supabase JWT
  const auth = req.headers.get("authorization")?.split("Bearer ")[1];
  if (!auth) return new Response("Unauthorized", { status: 401 });

  const { data: { user }, error: authError } = await supabase.auth.getUser(auth);
  if (authError || !user) return new Response("Unauthorized", { status: 401 });

  try {
    const payload = await req.json() as InboundPayload;

    const user_id = user.id;

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
