// =============================================
// WhatsApp API Integration
// =============================================
// This module handles sending WhatsApp messages via WhatsApp Cloud API
// or alternative providers like Twilio, MessageBird, etc.

import { WhatsAppMessage } from './types.ts';

// Environment variables
const WHATSAPP_API_URL = Deno.env.get('WHATSAPP_API_URL');
const WHATSAPP_API_TOKEN = Deno.env.get('WHATSAPP_API_TOKEN');
const WHATSAPP_PHONE_NUMBER_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');

/**
 * Send WhatsApp message using WhatsApp Cloud API
 * Documentation: https://developers.facebook.com/docs/whatsapp/cloud-api
 */
export async function sendWhatsAppMessage(
  message: WhatsAppMessage
): Promise<{ success: boolean; error?: string; messageId?: string }> {
  try {
    // Validate configuration
    if (!WHATSAPP_API_URL || !WHATSAPP_API_TOKEN || !WHATSAPP_PHONE_NUMBER_ID) {
      console.error('WhatsApp configuration missing:', {
        hasUrl: !!WHATSAPP_API_URL,
        hasToken: !!WHATSAPP_API_TOKEN,
        hasPhoneId: !!WHATSAPP_PHONE_NUMBER_ID,
      });
      return {
        success: false,
        error: 'WhatsApp API configuration is incomplete',
      };
    }

    // Format phone number (remove any non-numeric characters except +)
    const formattedPhone = formatPhoneNumber(message.to);

    // Prepare request body for WhatsApp Cloud API
    const requestBody = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: formattedPhone,
      type: 'text',
      text: {
        preview_url: true, // Enable link previews
        body: message.message,
      },
    };

    console.log('Sending WhatsApp message:', {
      to: formattedPhone,
      messageLength: message.message.length,
    });

    // Send request to WhatsApp Cloud API
    const response = await fetch(
      `${WHATSAPP_API_URL}/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${WHATSAPP_API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      }
    );

    const responseData = await response.json();

    if (!response.ok) {
      console.error('WhatsApp API error:', responseData);
      return {
        success: false,
        error: responseData.error?.message || 'Failed to send WhatsApp message',
      };
    }

    console.log('WhatsApp message sent successfully:', {
      messageId: responseData.messages?.[0]?.id,
      to: formattedPhone,
    });

    return {
      success: true,
      messageId: responseData.messages?.[0]?.id,
    };
  } catch (error) {
    console.error('Error sending WhatsApp message:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Format phone number for WhatsApp API
 * Accepts: 9123456789 or +919123456789
 * Returns: 919123456789 (country code + number without +)
 */
function formatPhoneNumber(phone: string): string {
  // Remove all non-numeric characters except +
  let cleaned = phone.replace(/[^\d+]/g, '');

  // If starts with +91, remove the +
  if (cleaned.startsWith('+91')) {
    cleaned = cleaned.substring(1);
  }
  // If starts with 91 and is 12 digits, keep as is
  else if (cleaned.startsWith('91') && cleaned.length === 12) {
    // Already in correct format
  }
  // If 10 digits, add 91 country code
  else if (cleaned.length === 10) {
    cleaned = '91' + cleaned;
  }
  // If starts with +, remove it
  else if (cleaned.startsWith('+')) {
    cleaned = cleaned.substring(1);
  }

  return cleaned;
}

/**
 * Format message with emojis properly encoded
 */
export function formatMessage(template: string, variables: Record<string, string>): string {
  let message = template;

  // Replace all variables
  for (const [key, value] of Object.entries(variables)) {
    message = message.replace(new RegExp(`{${key}}`, 'g'), value);
  }

  return message.trim();
}

/**
 * Validate Indian phone number
 */
export function isValidIndianPhone(phone: string): boolean {
  const cleaned = phone.replace(/\D/g, '');

  // Must be 10 digits starting with 6-9
  if (cleaned.length === 10 && /^[6-9]/.test(cleaned)) {
    return true;
  }

  // Or 12 digits starting with 91
  if (cleaned.length === 12 && cleaned.startsWith('91') && /^91[6-9]/.test(cleaned)) {
    return true;
  }

  return false;
}

// =============================================
// Message Templates
// =============================================

export const MESSAGE_TEMPLATES = {
  TOKEN_CONFIRMATION: `🏥 {clinic_name}

✅ Appointment Confirmed

Hi {patient_name}! 👋

🎫 Token: {token_number}

👨‍⚕️ Doctor: Dr. {doctor_name} ({specialization})

📅 Date: {appointment_date}

📍 Your Position: {queue_position}th in line

📱 Track Live: {tracking_url}

🔔 You'll receive an alert when you reach the 5th position.

Thank you for choosing {clinic_name}! 🙏`,

  QUEUE_ALERT: `🏥 {clinic_name}

⚡ Queue Alert

Hi {patient_name}! 🎯

You're almost there!

🎫 Your Token: {token_number}

👨‍⚕️ Doctor: Dr. {doctor_name}

📍 Current Position: 5th in line

🔔 Currently Calling: {current_token}

⏰ Estimated Wait: ~10-15 minutes

⚠️ Please be present in the waiting area.

📱 Track Live: {tracking_url}

Thank you for your patience! 🙏`,

  REVIEW_REQUEST: `🏥 {clinic_name}

✅ Visit Completed

Hi {patient_name}! 👋

Thank you for visiting us today! We hope you had a great experience with Dr. {doctor_name}.

⭐ Help Us Improve!

Your feedback helps us serve you better.

📝 Share Your Experience:

{review_link}

It takes just 30 seconds! 🙏

💙 Thank you for choosing {clinic_name}!

📞 Need another appointment? Call us anytime.`,
};
