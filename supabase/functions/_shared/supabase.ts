// =============================================
// Supabase Client for Edge Functions
// =============================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Create Supabase client with service role key
 * Service role bypasses RLS for Edge Functions
 */
export function createSupabaseClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing Supabase configuration');
  }

  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
