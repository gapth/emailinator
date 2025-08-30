export interface Deps {
  supabase: any;
  depositNanoUsd: number;
  serviceRoleKey: string;
}

export function createHandler({ supabase, depositNanoUsd, serviceRoleKey }: Deps) {
  return async function handler(req: Request): Promise<Response> {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    const auth = req.headers.get("authorization");
    if (auth !== `Bearer ${serviceRoleKey}`) return new Response("Unauthorized", { status: 401 });

    const { user_id } = await req.json() as { user_id?: string };
    if (!user_id) return new Response("user_id required", { status: 400 });

    const { data: existing, error } = await supabase
      .from("processing_budgets")
      .select("remaining_nano_usd")
      .eq("user_id", user_id)
      .single();

    const current = error ? 0 : existing.remaining_nano_usd;
    const newBalance = current + depositNanoUsd;

    const { error: upsertError } = await supabase
      .from("processing_budgets")
      .upsert({ user_id, remaining_nano_usd: newBalance });
    if (upsertError) return new Response(upsertError.message, { status: 500 });

    return new Response(
      JSON.stringify({ new_balance: newBalance }),
      { headers: { "content-type": "application/json" } },
    );
  };
}

if (import.meta.main) {
  const { createClient } = await import("jsr:@supabase/supabase-js@2");
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const depositNanoUsd = Number(Deno.env.get("BUDGET_DEPOSIT_NANO_USD") ?? "0");
  const handler = createHandler({ supabase, depositNanoUsd, serviceRoleKey: SERVICE_ROLE });
  Deno.serve(handler);
}
