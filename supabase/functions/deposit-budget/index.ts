export interface Deps {
  supabase: any;
  depositNanoUsd: number;
  maxAccruedNanoUsd: number;
  serviceRoleKey: string;
}

export function createHandler({
  supabase,
  depositNanoUsd,
  maxAccruedNanoUsd,
  serviceRoleKey,
}: Deps) {
  return async function handler(req: Request): Promise<Response> {
    if (req.method !== 'POST')
      return new Response('Method Not Allowed', { status: 405 });

    const auth = req.headers.get('authorization');
    if (auth !== `Bearer ${serviceRoleKey}`)
      return new Response('Unauthorized', { status: 401 });

    // Get all users to deposit budget for everyone
    const { data: users, error: usersError } =
      await supabase.auth.admin.listUsers();
    if (usersError) return new Response(usersError.message, { status: 500 });

    const results = [];

    for (const user of users.users) {
      const { data, error } = await supabase.rpc(
        'increment_processing_budget',
        {
          p_user_id: user.id,
          p_amount: depositNanoUsd,
          p_max_budget: maxAccruedNanoUsd,
        }
      );

      if (error) {
        console.error(`Failed to increment budget for user ${user.id}:`, error);
        results.push({ user_id: user.id, error: error.message });
      } else {
        results.push({ user_id: user.id, new_balance: data });
      }
    }

    return new Response(
      JSON.stringify({
        deposited_amount: depositNanoUsd,
        max_budget: maxAccruedNanoUsd,
        users_processed: results.length,
        results,
      }),
      {
        headers: { 'content-type': 'application/json' },
      }
    );
  };
}

if (import.meta.main) {
  const { createClient } = await import('jsr:@supabase/supabase-js@2');
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const depositNanoUsd = Number(Deno.env.get('BUDGET_DEPOSIT_NANO_USD') ?? '0');
  const maxAccruedNanoUsd = Number(
    Deno.env.get('BUDGET_MAX_ACCRUED_NANO_USD') ?? '0'
  );
  const handler = createHandler({
    supabase,
    depositNanoUsd,
    maxAccruedNanoUsd,
    serviceRoleKey: SERVICE_ROLE,
  });
  Deno.serve(handler);
}
