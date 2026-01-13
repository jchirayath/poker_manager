# Setting up env.json for Email Template Updates

## Step 1: Get Your Access Token

1. Go to https://supabase.com/dashboard/account/tokens
2. Click **"Generate New Token"**
3. Name it something like: `Email Template Updates`
4. Copy the token (it starts with `sbp_`)

## Step 2: Add Token to env.json

Open `env.json` in your project root and add the `SUPABASE_ACCESS_TOKEN` field:

**Before:**
```json
{
  "SUPABASE_URL": "https://evmicivjkcspqpnbjcus.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "SUPABASE_SERVICE_ROLE_KEY": "eyJhbGc...",
  "SUPABASE_DB_URL": "https://evmicivjkcspqpnbjcus.supabase.co"
}
```

**After:**
```json
{
  "SUPABASE_URL": "https://evmicivjkcspqpnbjcus.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "SUPABASE_SERVICE_ROLE_KEY": "eyJhbGc...",
  "SUPABASE_DB_URL": "https://evmicivjkcspqpnbjcus.supabase.co",
  "SUPABASE_ACCESS_TOKEN": "sbp_paste_your_token_here"
}
```

## Step 3: Run the Update Script

```bash
cd supabase
npx tsx update_email_templates.ts
```

## Security Notes

⚠️ **Important:**
- The `env.json` file is already in `.gitignore` - it will NOT be committed to git
- Never share your access token publicly
- Tokens can be revoked and regenerated from the Supabase dashboard
- The access token is different from your API keys (anon/service role)

## What Each Token Is For

| Token | Purpose | Where It's Used |
|-------|---------|----------------|
| `SUPABASE_ANON_KEY` | Client-side API access | Flutter app |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side admin access | Backend operations |
| `SUPABASE_ACCESS_TOKEN` | Management API access | This script (updating templates) |

The access token is used to modify project settings via the Supabase Management API, which is separate from the database API keys.
