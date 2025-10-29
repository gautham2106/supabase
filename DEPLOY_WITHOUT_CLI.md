# Deploy Edge Functions WITHOUT CLI

This guide shows you how to deploy Edge Functions without using terminal/CLI directly on your computer.

---

## Why CLI is Required (Technical Explanation)

Edge Functions are **deployed as compiled Deno/TypeScript code** that needs to be:
1. Bundled with dependencies
2. Compiled to executable format
3. Uploaded to Supabase edge network
4. Registered with your project

The Dashboard UI doesn't have these compilation tools, which is why CLI is needed.

---

## 🎯 Solution 1: Use GitHub Actions (No Local CLI Needed)

Deploy automatically from GitHub whenever you push code!

### Prerequisites
- GitHub account
- Code pushed to GitHub repository

### Setup Steps (10 minutes)

#### 1. Push Code to GitHub

If not already done:
```bash
# One-time setup
git init
git add .
git commit -m "Add Edge Functions"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

#### 2. Get Supabase Access Token

1. Go to https://app.supabase.com/account/tokens
2. Click **Generate new token**
3. Name: `GitHub Actions`
4. Click **Generate token**
5. **Copy the token** (you won't see it again!)

#### 3. Add GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

Add these 2 secrets:

**Secret 1:**
- Name: `SUPABASE_ACCESS_TOKEN`
- Value: [paste token from step 2]

**Secret 2:**
- Name: `SUPABASE_PROJECT_REF`
- Value: Your project reference (e.g., `xyzabcdefg`)
  - Find it in your Supabase project URL: `https://app.supabase.com/project/[THIS-PART]`

#### 4. Add Workflow File

The workflow file `.github/workflows/deploy-functions.yml` is already in your repo!

#### 5. Push to Trigger Deployment

```bash
git add .
git commit -m "Add deployment workflow"
git push
```

#### 6. Watch Deployment

1. Go to your GitHub repo → **Actions** tab
2. You'll see "Deploy Edge Functions" workflow running
3. Click on it to see progress
4. Wait for green checkmark ✅

**That's it!** Functions are now deployed!

#### 7. Manual Trigger (Optional)

You can also trigger deployment manually:
1. Go to **Actions** tab
2. Click "Deploy Edge Functions"
3. Click **Run workflow** → **Run workflow**

---

## 🎯 Solution 2: Minimal CLI Usage (5 Minutes Total)

If GitHub Actions doesn't work, here's the absolute simplest CLI workflow.

### One-Time Setup (You Never Have to Do This Again)

#### For Windows Users

**Method A: PowerShell (Recommended)**

1. Open **PowerShell** (not CMD)
2. Copy-paste each command one by one:

```powershell
# Download Supabase CLI
Invoke-WebRequest -Uri "https://github.com/supabase/cli/releases/latest/download/supabase-windows-amd64.exe" -OutFile "$env:USERPROFILE\supabase.exe"

# Add to PATH temporarily
$env:Path += ";$env:USERPROFILE"

# Login (will open browser)
supabase login

# Link project (replace YOUR_PROJECT_REF)
supabase link --project-ref YOUR_PROJECT_REF

# Navigate to your functions folder
cd C:\path\to\your\supabase

# Deploy functions
supabase functions deploy send-whatsapp-token
supabase functions deploy send-queue-alerts
supabase functions deploy send-review-request
supabase functions deploy log-daily-usage
```

**Method B: Scoop (Alternative)**
```powershell
# Install Scoop (if not already installed)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Install Supabase CLI
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Then follow same steps as Method A (login, link, deploy)
```

#### For Mac Users

1. Open **Terminal**
2. Copy-paste these commands:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Supabase CLI
brew install supabase/tap/supabase

# Login (will open browser)
supabase login

# Link project (replace YOUR_PROJECT_REF)
supabase link --project-ref YOUR_PROJECT_REF

# Navigate to your functions folder
cd /path/to/your/supabase

# Deploy functions
supabase functions deploy send-whatsapp-token
supabase functions deploy send-queue-alerts
supabase functions deploy send-review-request
supabase functions deploy log-daily-usage
```

#### For Linux Users

```bash
# Install via Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install supabase/tap/supabase

# Or via direct download
curl -Lo supabase.tar.gz https://github.com/supabase/cli/releases/latest/download/supabase-linux-amd64.tar.gz
tar -xzf supabase.tar.gz
sudo mv supabase /usr/local/bin/

# Login and deploy (same as Mac)
supabase login
supabase link --project-ref YOUR_PROJECT_REF
cd /path/to/your/supabase
supabase functions deploy send-whatsapp-token
supabase functions deploy send-queue-alerts
supabase functions deploy send-review-request
supabase functions deploy log-daily-usage
```

---

## 🎯 Solution 3: Use Replit / CodeSandbox (Browser-Based)

Deploy from your browser without installing anything locally!

### Using Replit

1. Go to https://replit.com
2. Click **Create Repl**
3. Choose **Import from GitHub**
4. Paste your repo URL
5. Open **Shell** tab at bottom
6. Run deployment commands:

```bash
# Install Supabase CLI
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase-linux-amd64.tar.gz | tar -xz
./supabase login

# Link and deploy
./supabase link --project-ref YOUR_PROJECT_REF
cd supabase
../supabase functions deploy send-whatsapp-token
../supabase functions deploy send-queue-alerts
../supabase functions deploy send-review-request
../supabase functions deploy log-daily-usage
```

---

## 🎯 Solution 4: Ask Someone to Deploy For You

If you have a developer friend or team member:

1. Share the repository with them
2. They run these 3 commands:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy send-whatsapp-token send-queue-alerts send-review-request log-daily-usage
```

Done in 2 minutes!

---

## ✅ After Deployment (All Done from Dashboard)

Once functions are deployed (using any method above), configure everything else from Dashboard:

### 1. Set Environment Secrets

Dashboard → **Project Settings** → **Edge Functions** → **Add secret**

Add these secrets:
- `WHATSAPP_API_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_API_URL` = `https://graph.facebook.com/v18.0`
- `APP_URL` = `https://your-app.com`
- `SUPABASE_URL` (auto-set)
- `SUPABASE_SERVICE_ROLE_KEY` (auto-set)

### 2. Create Database Webhooks

Dashboard → **Database** → **Webhooks** → **Create a new hook**

**Webhook 1: Token Created**
- Name: `token_created`
- Table: `tokens`
- Events: ✅ Insert
- Type: HTTP Request
- Method: POST
- URL: `https://YOUR_PROJECT.supabase.co/functions/v1/send-whatsapp-token`
- Headers:
  ```json
  {"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}
  ```

**Webhook 2: Queue Alert**
- Name: `queue_alert`
- Table: `tokens`
- Events: ✅ Update
- Type: HTTP Request
- Method: POST
- URL: `https://YOUR_PROJECT.supabase.co/functions/v1/send-queue-alerts`
- Headers: (same as above)
- Conditions: `OLD.status != 'in consultation' AND NEW.status = 'in consultation'`

**Webhook 3: Review Request**
- Name: `review_request`
- Table: `tokens`
- Events: ✅ Update
- Type: HTTP Request
- Method: POST
- URL: `https://YOUR_PROJECT.supabase.co/functions/v1/send-review-request`
- Headers: (same as above)
- Conditions: `OLD.status != 'completed' AND NEW.status = 'completed'`

### 3. Create Cron Job

Dashboard → **Edge Functions** → **Cron Jobs** → **Create a new cron job**

- Name: `daily_usage_logging`
- Schedule: `0 23 * * *`
- Function: `log-daily-usage`
- Request body: `{}`

---

## 🧪 Test Functions (From Dashboard)

Dashboard → **Edge Functions** → Select function → **Invoke**

**Test send-whatsapp-token:**
```json
{
  "record": {
    "id": "your-token-uuid"
  }
}
```

View logs in the **Logs** tab!

---

## ❓ FAQ

### Q: Can I edit functions from Dashboard?
**A:** No, you must redeploy using CLI or GitHub Actions.

### Q: Do I need to deploy every time I change code?
**A:** Yes, but with GitHub Actions, just push to GitHub and it auto-deploys.

### Q: Can I delete functions from Dashboard?
**A:** No, use CLI: `supabase functions delete function-name`

### Q: Where do I find Project Reference?
**A:** URL: `https://app.supabase.com/project/[THIS-PART]`

### Q: What if deployment fails?
**A:** Check GitHub Actions logs or CLI error messages for details.

---

## 🎯 Recommended Approach

For most users, I recommend **Solution 1 (GitHub Actions)**:
- ✅ No local CLI needed
- ✅ Automatic deployments
- ✅ Version control
- ✅ Easy rollbacks
- ✅ Team-friendly

Just push code and it deploys automatically!

---

## 📞 Need Help?

If you're stuck:
1. Share your error message
2. Specify which solution you tried
3. I can provide more specific guidance

---

## 🎉 Once Deployed

After successful deployment, you'll see functions in:
- Dashboard → **Edge Functions** (list of functions)
- Can view logs, metrics, and invoke manually
- Can configure webhooks and cron jobs
- Never need CLI again (unless updating function code)

---

**Bottom line:** One-time CLI usage (5 minutes) or set up GitHub Actions (10 minutes one-time), then everything else is from Dashboard! 🚀
