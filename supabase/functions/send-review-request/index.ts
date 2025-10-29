// =============================================
// Edge Function: send-review-request
// =============================================
// Triggered: AFTER UPDATE on tokens table + 2 minute delay
// Condition: When status changes TO 'completed'
// Purpose: Request review after consultation
// =============================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient } from '../_shared/supabase.ts';
import {
  sendWhatsAppMessage,
  formatMessage,
  MESSAGE_TEMPLATES,
  isValidIndianPhone,
} from '../_shared/whatsapp.ts';

const DELAY_MINUTES = 2; // Wait 2 minutes after completion

serve(async (req) => {
  try {
    // Parse request body
    const { record, old_record } = await req.json();

    if (!record || !old_record) {
      return new Response(
        JSON.stringify({ error: 'Invalid request: missing records' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if status changed TO 'completed'
    if (old_record.status === 'completed' || record.status !== 'completed') {
      console.log('Status did not change to completed, skipping');
      return new Response(
        JSON.stringify({ message: 'Not a status change to completed' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('Token status changed to completed, scheduling review request:', record.id);

    // Wait 2 minutes before sending review request
    await new Promise((resolve) => setTimeout(resolve, DELAY_MINUTES * 60 * 1000));

    const supabase = createSupabaseClient();

    // Verify token is still completed (not changed during delay)
    const { data: currentToken, error: verifyError } = await supabase
      .from('tokens')
      .select('status')
      .eq('id', record.id)
      .single();

    if (verifyError || !currentToken) {
      console.error('Error verifying token status:', verifyError);
      return new Response(
        JSON.stringify({ error: 'Failed to verify token status' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (currentToken.status !== 'completed') {
      console.log('Token status changed during delay, skipping review request');
      return new Response(
        JSON.stringify({ message: 'Token status changed, skipping' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Fetch complete token details
    const { data: tokenData, error: fetchError } = await supabase
      .from('tokens')
      .select(`
        *,
        clinic:clinics!inner(*),
        doctor:doctors!inner(*),
        patient_family_member:patient_family_members!inner(
          *,
          patient:patients!inner(*)
        )
      `)
      .eq('id', record.id)
      .single();

    if (fetchError || !tokenData) {
      console.error('Error fetching token data:', fetchError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch token details' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if review requests are enabled
    if (!tokenData.clinic.whatsapp_review) {
      console.log('Review requests disabled for clinic:', tokenData.clinic.id);
      return new Response(
        JSON.stringify({ message: 'Review requests disabled' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if clinic has review link
    if (!tokenData.clinic.review_link) {
      console.log('No review link configured for clinic:', tokenData.clinic.id);
      return new Response(
        JSON.stringify({ message: 'No review link configured' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Get patient phone
    const patientPhone = tokenData.patient_family_member.patient.phone_number;

    // Validate phone number
    if (!isValidIndianPhone(patientPhone)) {
      console.error('Invalid phone number:', patientPhone);
      return new Response(
        JSON.stringify({ error: 'Invalid phone number' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Prepare message variables
    const variables = {
      clinic_name: tokenData.clinic.name,
      patient_name: tokenData.patient_family_member.name,
      doctor_name: tokenData.doctor.name,
      review_link: tokenData.clinic.review_link,
    };

    // Format message
    const message = formatMessage(MESSAGE_TEMPLATES.REVIEW_REQUEST, variables);

    // Send WhatsApp message
    const result = await sendWhatsAppMessage({
      to: patientPhone,
      message: message,
    });

    if (result.success) {
      console.log('Review request sent successfully:', {
        tokenId: tokenData.id,
        messageId: result.messageId,
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Review request sent',
          messageId: result.messageId,
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    } else {
      console.error('Failed to send review request:', result.error);
      return new Response(
        JSON.stringify({
          success: false,
          error: result.error,
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  } catch (error) {
    console.error('Error in send-review-request:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
