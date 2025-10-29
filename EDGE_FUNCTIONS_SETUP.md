# Edge Functions Setup Guide

This guide will help you deploy and configure the WhatsApp integration Edge Functions for your Hospital Token & Queue Management System.

## Prerequisites

- ✅ Supabase project created
- ✅ Database schema executed (`schema.sql`, `triggers.sql`)
- ✅ Supabase CLI installed
- ✅ WhatsApp Business API access

---

## Table of Contents

1. [Install Supabase CLI](#install-supabase-cli)
2. [WhatsApp API Setup](#whatsapp-api-setup)
3. [Configure Environment Variables](#configure-environment-variables)
4. [Deploy Edge Functions](#deploy-edge-functions)
5. [Configure Database Webhooks](#configure-database-webhooks)
6. [Configure Cron Jobs](#configure-cron-jobs)
7. [Testing](#testing)
8. [Monitoring & Logs](#monitoring--logs)

---

## Install Supabase CLI

### macOS / Linux
```bash
brew install supabase/tap/supabase
```

### Windows
```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### Verify Installation
```bash
supabase --version
```

---

## WhatsApp API Setup

You have two options for WhatsApp integration:

### Option 1: WhatsApp Cloud API (Recommended - Free)

1. **Create Facebook App**
   - Go to https://developers.facebook.com/apps
   - Create a new app → Choose "Business" type
   - Add "WhatsApp" product

2. **Get API Credentials**
   - Go to WhatsApp → API Setup
   - Copy **Phone Number ID**
   - Copy **Access Token** (temporary)

3. **Generate Permanent Access Token**
   - Go to Business Settings → System Users
   - Create system user → Assign WhatsApp permissions
   - Generate permanent token
   - **Important:** Save this token securely!

4. **Verify Phone Number**
   - Add your business phone number
   - Complete verification process
   - Enable account for production

5. **Register Test Numbers** (During Development)
   - Go to WhatsApp → API Setup → Send and receive messages
   - Add test phone numbers (up to 5 for testing)

### Option 2: Twilio WhatsApp API (Paid)

1. Sign up at https://www.twilio.com
2. Get WhatsApp enabled phone number
3. Copy Account SID and Auth Token
4. Update Edge Functions to use Twilio API (see code comments)

---

## Configure Environment Variables

### 1. Link to Your Supabase Project

```bash
cd supabase
supabase login
supabase link --project-ref your-project-ref
```

### 2. Set Environment Secrets

Set these secrets for ALL Edge Functions:

```bash
# Supabase Configuration
supabase secrets set SUPABASE_URL=https://your-project.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Application URL
supabase secrets set APP_URL=https://your-app.com

# WhatsApp Cloud API
supabase secrets set WHATSAPP_API_URL=https://graph.facebook.com/v18.0
supabase secrets set WHATSAPP_API_TOKEN=your-permanent-access-token
supabase secrets set WHATSAPP_PHONE_NUMBER_ID=your-phone-number-id
```

### 3. Verify Secrets

```bash
supabase secrets list
```

Expected output:
```
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
APP_URL
WHATSAPP_API_URL
WHATSAPP_API_TOKEN
WHATSAPP_PHONE_NUMBER_ID
```

---

## Deploy Edge Functions

### 1. Deploy All Functions

```bash
cd supabase

# Deploy send-whatsapp-token
supabase functions deploy send-whatsapp-token

# Deploy send-queue-alerts
supabase functions deploy send-queue-alerts

# Deploy send-review-request
supabase functions deploy send-review-request

# Deploy log-daily-usage
supabase functions deploy log-daily-usage
```

### 2. Verify Deployment

```bash
supabase functions list
```

Expected output:
```
send-whatsapp-token      deployed
send-queue-alerts        deployed
send-review-request      deployed
log-daily-usage          deployed
```

### 3. Get Function URLs

Note down the URLs (you'll need them for webhooks):

```
https://your-project-ref.supabase.co/functions/v1/send-whatsapp-token
https://your-project-ref.supabase.co/functions/v1/send-queue-alerts
https://your-project-ref.supabase.co/functions/v1/send-review-request
https://your-project-ref.supabase.co/functions/v1/log-daily-usage
```

---

## Configure Database Webhooks

Webhooks trigger Edge Functions when database events occur.

### 1. Navigate to Webhooks

1. Go to Supabase Dashboard
2. Click **Database** → **Webhooks**
3. Click **Create a new hook**

### 2. Create Webhook: Token Created

**Settings:**

| Field | Value |
|-------|-------|
| **Name** | `token_created_webhook` |
| **Table** | `tokens` |
| **Events** | ✅ Insert |
| **Type** | `HTTP Request` |
| **Method** | `POST` |
| **URL** | `https://your-project-ref.supabase.co/functions/v1/send-whatsapp-token` |

**HTTP Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer YOUR_ANON_KEY"
}
```

**Conditions:** (Optional)
```sql
-- Only trigger for active clinics
EXISTS (SELECT 1 FROM clinics WHERE id = NEW.clinic_id AND is_active = true)
```

Click **Create webhook**

### 3. Create Webhook: Token Status Updated (Queue Alerts)

**Settings:**

| Field | Value |
|-------|-------|
| **Name** | `token_status_updated_queue_webhook` |
| **Table** | `tokens` |
| **Events** | ✅ Update |
| **Type** | `HTTP Request` |
| **Method** | `POST` |
| **URL** | `https://your-project-ref.supabase.co/functions/v1/send-queue-alerts` |

**HTTP Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer YOUR_ANON_KEY"
}
```

**Conditions:**
```sql
-- Only trigger when status changes TO 'in consultation'
OLD.status != 'in consultation' AND NEW.status = 'in consultation'
```

Click **Create webhook**

### 4. Create Webhook: Token Completed (Review Requests)

**Settings:**

| Field | Value |
|-------|-------|
| **Name** | `token_completed_review_webhook` |
| **Table** | `tokens` |
| **Events** | ✅ Update |
| **Type** | `HTTP Request` |
| **Method** | `POST` |
| **URL** | `https://your-project-ref.supabase.co/functions/v1/send-review-request` |

**HTTP Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer YOUR_ANON_KEY"
}
```

**Conditions:**
```sql
-- Only trigger when status changes TO 'completed'
OLD.status != 'completed' AND NEW.status = 'completed'
```

Click **Create webhook**

---

## Configure Cron Jobs

Cron jobs run Edge Functions on a schedule.

### 1. Create Cron Job: Daily Usage Logging

1. Go to Supabase Dashboard
2. Click **Edge Functions**
3. Click **Cron Jobs** tab
4. Click **Create a new cron job**

**Settings:**

| Field | Value |
|-------|-------|
| **Name** | `daily-usage-logging` |
| **Schedule** | `0 23 * * *` (Daily at 23:00 UTC) |
| **Function** | `log-daily-usage` |
| **Request Body** | `{}` (empty JSON object) |

**Schedule Explanation:**
```
0 23 * * *
│  │  │ │ │
│  │  │ │ └─ Day of week (0-7, Sunday = 0 or 7)
│  │  │ └─── Month (1-12)
│  │  └───── Day of month (1-31)
│  └──────── Hour (0-23)
└─────────── Minute (0-59)
```

Common schedules:
- `0 23 * * *` - Daily at 11 PM
- `0 0 * * *` - Daily at midnight
- `0 */6 * * *` - Every 6 hours
- `*/30 * * * *` - Every 30 minutes

Click **Create cron job**

---

## Testing

### Test 1: Token Creation (WhatsApp Confirmation)

```sql
-- In SQL Editor
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES (
  'your-clinic-id',
  'your-doctor-id',
  'your-patient-family-member-id',
  'TEST1',
  CURRENT_DATE
);
```

**Expected:** WhatsApp message sent to patient within 5 seconds

**Verify:**
1. Check patient's WhatsApp
2. Check Edge Function logs (Dashboard → Edge Functions → Logs)
3. Message should match the Token Confirmation template

### Test 2: Queue Alert (5th Position)

```sql
-- Create 5 tokens
-- Then update 1st token to 'in consultation'
UPDATE tokens
SET status = 'in consultation'
WHERE token_number = 'TEST1' AND date = CURRENT_DATE;
```

**Expected:** 5th waiting patient receives queue alert

**Verify:**
1. Check 5th patient's WhatsApp
2. Message should show "Current Position: 5th in line"
3. Should show current token being called

### Test 3: Review Request (After Completion)

```sql
-- Complete a consultation
UPDATE tokens
SET status = 'completed'
WHERE token_number = 'TEST1' AND date = CURRENT_DATE;
```

**Expected:** Review request sent after 2-minute delay

**Verify:**
1. Wait 2 minutes
2. Check patient's WhatsApp
3. Message should include review link

### Test 4: Daily Usage Logging (Manual Trigger)

```bash
# Invoke function manually
curl -X POST \
  "https://your-project-ref.supabase.co/functions/v1/log-daily-usage" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected:** Usage logs created in `usage_logs` table

**Verify:**
```sql
SELECT * FROM usage_logs
WHERE date = CURRENT_DATE
ORDER BY clinic_id;
```

### Test 5: View Edge Function Logs

```bash
# View logs for specific function
supabase functions logs send-whatsapp-token

# Follow logs in real-time
supabase functions logs send-whatsapp-token --follow
```

---

## Monitoring & Logs

### Dashboard Logs

1. Go to Dashboard → **Edge Functions**
2. Select a function
3. Click **Logs** tab
4. View recent invocations, errors, and execution time

### CLI Logs

```bash
# View logs for all functions
supabase functions logs

# View logs for specific function
supabase functions logs send-whatsapp-token

# Follow logs in real-time
supabase functions logs send-whatsapp-token --follow

# Filter by time
supabase functions logs send-whatsapp-token --since 1h
```

### Error Monitoring

Common errors and solutions:

#### Error: "WhatsApp API configuration is incomplete"
**Solution:** Check environment secrets are set correctly
```bash
supabase secrets list
```

#### Error: "Failed to send WhatsApp message"
**Solution:**
1. Verify WhatsApp API token is valid
2. Check phone number is registered/verified
3. Ensure recipient number is in correct format (919123456789)

#### Error: "Invalid phone number"
**Solution:** Phone must be 10 digits starting with 6-9 (Indian format)

#### Error: "Daily token limit reached"
**Solution:** Working as intended - increase clinic's token_daily_limit

### Performance Metrics

Monitor in Dashboard → Edge Functions:

- **Invocations:** Total function calls
- **Errors:** Failed executions
- **Duration:** Average execution time
- **Billing:** Function usage costs

---

## Troubleshooting

### Webhook Not Triggering

1. Check webhook is enabled (Dashboard → Database → Webhooks)
2. Verify condition SQL is correct
3. Test webhook manually (click "Send test webhook")
4. Check Edge Function logs for errors

### WhatsApp Message Not Received

1. **Verify phone number format:**
   ```sql
   SELECT phone_number FROM patients WHERE id = 'patient-id';
   -- Should be: 9123456789 or +919123456789
   ```

2. **Check WhatsApp Business account status:**
   - Go to Facebook Business Manager
   - Verify account is active and approved

3. **Test with registered number:**
   - During development, only registered test numbers work
   - Add your number in WhatsApp API Setup → Test numbers

4. **Check rate limits:**
   - Free tier: 1,000 messages/month
   - Check quota in Facebook Business Manager

### Function Timeout

If function times out (especially send-review-request with 2-minute delay):

1. Increase timeout in config.toml:
   ```toml
   [[edge_runtime.functions]]
   name = "send-review-request"
   verify_jwt = false
   timeout = 300  # 5 minutes
   ```

2. Redeploy function

### Debugging Tips

1. **Add console.log statements:**
   ```typescript
   console.log('Token data:', tokenData);
   console.log('Sending WhatsApp to:', patientPhone);
   ```

2. **Test function locally:**
   ```bash
   supabase functions serve send-whatsapp-token
   ```

3. **Invoke function manually:**
   ```bash
   curl -X POST \
     "http://localhost:54321/functions/v1/send-whatsapp-token" \
     -H "Content-Type: application/json" \
     -d '{"record": {"id": "token-uuid"}}'
   ```

---

## Cost Considerations

### WhatsApp Cloud API (Free Tier)
- **Free:** 1,000 conversations/month
- **Paid:** $0.005 - $0.02 per conversation (depends on country)
- **Conversation:** 24-hour window for unlimited messages

### Supabase Edge Functions
- **Free:** 500,000 invocations/month
- **Paid:** $2 per 1M invocations

### Estimated Monthly Cost (100 tokens/day)

| Item | Quantity | Cost |
|------|----------|------|
| Token confirmations | 3,000 | $0.15 - $0.60 |
| Queue alerts | ~600 | $0.03 - $0.12 |
| Review requests | ~2,400 | $0.12 - $0.48 |
| **Total WhatsApp** | ~6,000 | **$0.30 - $1.20** |
| Edge Functions | ~6,000 | **$0.00** (within free tier) |
| **Total Monthly** | | **< $2** |

---

## Security Best Practices

1. **Never commit secrets:**
   - Add `.env` to `.gitignore`
   - Use Supabase secrets management

2. **Use service role key carefully:**
   - Only use in Edge Functions (server-side)
   - Never expose in frontend code

3. **Validate phone numbers:**
   - Already implemented in helper functions
   - Prevents sending to invalid numbers

4. **Rate limiting:**
   - Implemented via token_daily_limit
   - Consider adding per-user limits if needed

5. **Monitor logs regularly:**
   - Check for unusual activity
   - Set up alerts for errors

---

## Next Steps

After completing this setup:

1. ✅ Test all 4 Edge Functions
2. ✅ Verify webhooks trigger correctly
3. ✅ Confirm WhatsApp messages are received
4. ✅ Monitor logs for first 24 hours
5. ⏭️ Build frontend UI
6. ⏭️ Deploy to production
7. ⏭️ Set up monitoring alerts

---

## Support Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [WhatsApp Cloud API Docs](https://developers.facebook.com/docs/whatsapp/cloud-api)
- [Supabase Database Webhooks](https://supabase.com/docs/guides/database/webhooks)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli)

---

Happy deploying! 🚀
