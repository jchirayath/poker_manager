# Quick Start: Updating Email Templates

## TL;DR

```bash
# 1. Add your access token to env.json
# "SUPABASE_ACCESS_TOKEN": "sbp_your_token_here"

# 2. Run the update
cd supabase
npx tsx update_email_templates.ts
```

## Detailed Steps

### 1. Get Your Access Token

- Go to https://supabase.com/dashboard/account/tokens
- Click "Generate New Token"
- Give it a name like "Email Template Updates"
- Copy the token (starts with `sbp_`)

### 2. Add Token to env.json

Edit your `env.json` file in the project root and add the access token:

```json
{
  "SUPABASE_URL": "https://evmicivjkcspqpnbjcus.supabase.co",
  "SUPABASE_ANON_KEY": "...",
  "SUPABASE_SERVICE_ROLE_KEY": "...",
  "SUPABASE_DB_URL": "...",
  "SUPABASE_ACCESS_TOKEN": "sbp_your_token_here"
}
```

**Note:** The project reference is automatically extracted from `SUPABASE_URL`.

### 3. Update Templates

**Option A: Using TypeScript (recommended)**
```bash
cd supabase
npx tsx update_email_templates.ts
```

**Option B: Using Bash script**
```bash
cd supabase
./update_email_templates.sh
```

**Option C: Using Make**
```bash
cd supabase
make update-templates
```

### 4. Verify

- Go to your Supabase Dashboard
- Navigate to **Authentication** → **Email Templates**
- Check that the templates have been updated
- Send a test email to verify formatting

## Making Changes

1. Edit [EMAIL_TEMPLATES.md](./EMAIL_TEMPLATES.md)
2. Run the update command again
3. Test the changes

## Troubleshooting

**"env.json file not found"**
- Make sure you're running the script with env.json in the project root
- The env.json should be one directory up from the supabase folder

**"SUPABASE_ACCESS_TOKEN is not set in env.json"**
- Add the access token field to your env.json file
- Make sure it's a valid token starting with `sbp_`

**"npx: command not found"**
- Install Node.js from https://nodejs.org/

**"jq: command not found"** (only for bash script)
- macOS: `brew install jq`
- Linux: `sudo apt-get install jq`

**"HTTP 401" error**
- Your access token is invalid or expired
- Generate a new token from the dashboard

**Templates not showing in dashboard**
- Wait 2-3 minutes for changes to propagate
- Refresh the dashboard page
- Check the script output for errors

## Need Help?

See [UPDATE_EMAIL_TEMPLATES_README.md](./UPDATE_EMAIL_TEMPLATES_README.md) for detailed documentation.
