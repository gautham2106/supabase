// =============================================
// Edge Function: log-daily-usage
// =============================================
// Triggered: Cron job (daily at 23:59)
// Purpose: Log daily usage statistics for billing
// =============================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient } from '../_shared/supabase.ts';

serve(async (req) => {
  try {
    console.log('Starting daily usage logging...');

    const supabase = createSupabaseClient();

    // Get today's date
    const today = new Date().toISOString().split('T')[0];

    // Fetch all active clinics
    const { data: clinics, error: clinicsError } = await supabase
      .from('clinics')
      .select('id, name, whatsapp_confirmation, whatsapp_queue_alert, whatsapp_review')
      .eq('is_active', true);

    if (clinicsError) {
      console.error('Error fetching clinics:', clinicsError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch clinics' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (!clinics || clinics.length === 0) {
      console.log('No active clinics found');
      return new Response(
        JSON.stringify({ message: 'No active clinics' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Processing ${clinics.length} active clinics`);

    const results = [];

    // Process each clinic
    for (const clinic of clinics) {
      try {
        // Count tokens generated today
        const { count: tokensGenerated, error: tokensError } = await supabase
          .from('tokens')
          .select('*', { count: 'exact', head: true })
          .eq('clinic_id', clinic.id)
          .eq('date', today);

        if (tokensError) {
          console.error(`Error counting tokens for clinic ${clinic.id}:`, tokensError);
          continue;
        }

        // Calculate WhatsApp messages sent
        let whatsappSent = 0;

        // Confirmation messages (1 per token if enabled)
        if (clinic.whatsapp_confirmation) {
          whatsappSent += tokensGenerated || 0;
        }

        // Queue alerts (estimate: ~20% of tokens get queue alerts)
        if (clinic.whatsapp_queue_alert) {
          const { count: alertsSent } = await supabase
            .from('tokens')
            .select('*', { count: 'exact', head: true })
            .eq('clinic_id', clinic.id)
            .eq('date', today)
            .eq('reminder_sent', true);

          whatsappSent += alertsSent || 0;
        }

        // Review requests (1 per completed token if enabled)
        if (clinic.whatsapp_review) {
          const { count: completedTokens } = await supabase
            .from('tokens')
            .select('*', { count: 'exact', head: true })
            .eq('clinic_id', clinic.id)
            .eq('date', today)
            .eq('status', 'completed');

          whatsappSent += completedTokens || 0;
        }

        // Insert or update usage log
        const { error: upsertError } = await supabase
          .from('usage_logs')
          .upsert(
            {
              clinic_id: clinic.id,
              date: today,
              tokens_generated: tokensGenerated || 0,
              whatsapp_sent: whatsappSent,
              created_at: new Date().toISOString(),
            },
            {
              onConflict: 'clinic_id,date',
            }
          );

        if (upsertError) {
          console.error(`Error upserting usage log for clinic ${clinic.id}:`, upsertError);
          continue;
        }

        results.push({
          clinic_id: clinic.id,
          clinic_name: clinic.name,
          tokens_generated: tokensGenerated || 0,
          whatsapp_sent: whatsappSent,
        });

        console.log(`Logged usage for clinic ${clinic.name}:`, {
          tokens: tokensGenerated,
          whatsapp: whatsappSent,
        });
      } catch (error) {
        console.error(`Error processing clinic ${clinic.id}:`, error);
        continue;
      }
    }

    console.log('Daily usage logging completed:', {
      clinics_processed: results.length,
      total_tokens: results.reduce((sum, r) => sum + r.tokens_generated, 0),
      total_whatsapp: results.reduce((sum, r) => sum + r.whatsapp_sent, 0),
    });

    return new Response(
      JSON.stringify({
        success: true,
        date: today,
        clinics_processed: results.length,
        results: results,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in log-daily-usage:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
