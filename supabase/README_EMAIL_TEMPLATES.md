# Email Template Management - Complete Guide

This guide explains how to programmatically update Supabase email templates for the Poker Manager app.

## Quick Start (30 seconds)

```bash
# 1. Add your access token to env.json (see ENV_SETUP.md)
# 2. Run the update
cd supabase
npx tsx update_email_templates.ts
```

## What This Does

The scripts in this directory allow you to:
- ✅ Update all 4 Supabase email templates from a single markdown file
- ✅ Maintain templates in version control
- ✅ Deploy template updates without manual copy/paste
- ✅ Keep consistent branding across all auth emails

## Files Overview

| File | Purpose |
|------|---------|
| [EMAIL_TEMPLATES.md](EMAIL_TEMPLATES.md) | Source of truth for all email templates |
| [update_email_templates.ts](update_email_templates.ts) | TypeScript update script (recommended) |
| [update_email_templates.sh](update_email_templates.sh) | Bash update script (alternative) |
| [ENV_SETUP.md](ENV_SETUP.md) | How to configure env.json with access token |
| [QUICK_START.md](QUICK_START.md) | Quick reference guide |
| [UPDATE_EMAIL_TEMPLATES_README.md](UPDATE_EMAIL_TEMPLATES_README.md) | Detailed documentation |
| [test_config.ts](test_config.ts) | Verify your env.json configuration |
| [Makefile](Makefile) | Convenient make commands |

## Setup Instructions

### 1. Test Current Configuration

```bash
cd supabase
npx tsx test_config.ts
```

This will show you if your `env.json` is configured correctly.

### 2. Add Access Token

Follow the instructions in [ENV_SETUP.md](ENV_SETUP.md) to:
1. Generate a Supabase access token
2. Add it to your `env.json` file

### 3. Run the Update

```bash
cd supabase
npx tsx update_email_templates.ts
```

You should see output like:
```
🚀 Starting email template update...

📋 Using project: evmicivjkcspqpnbjcus
📁 Reading templates from: EMAIL_TEMPLATES.md

📄 Found 4 templates to update

📧 Updating Confirm Signup...
✅ Successfully updated Confirm Signup

📧 Updating Reset Password...
✅ Successfully updated Reset Password

📧 Updating Magic Link...
✅ Successfully updated Magic Link

📧 Updating Invite User...
✅ Successfully updated Invite User

✨ Successfully updated 4/4 email templates!
⏱️  Note: Changes may take a few minutes to propagate.
```

## The Four Templates

1. **Confirm Signup** - Sent when new users register
2. **Reset Password** - Sent when users request password reset
3. **Magic Link** - Sent for passwordless login (if enabled)
4. **Invite User** - Sent when inviting users to poker groups

All templates feature:
- 🎨 Poker Manager branding (green gradient, spade icon)
- 🏷️ Beta badge
- 📱 Mobile-responsive design
- 🎯 Clear call-to-action buttons

## Workflow for Updating Templates

```bash
# 1. Edit EMAIL_TEMPLATES.md with your changes
vim EMAIL_TEMPLATES.md

# 2. Run the update script
npx tsx update_email_templates.ts

# 3. Wait 2-3 minutes for changes to propagate

# 4. Test by triggering the auth flow
# (e.g., sign up with a new email to test the confirmation email)
```

## Using Make Commands

```bash
cd supabase

# Show help
make help

# Update templates (runs TypeScript version)
make update-templates

# Update templates using bash script
make update-templates-sh
```

## Configuration Details

The scripts read from `env.json` in your project root:

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "...",
  "SUPABASE_SERVICE_ROLE_KEY": "...",
  "SUPABASE_DB_URL": "...",
  "SUPABASE_ACCESS_TOKEN": "sbp_your_token_here"
}
```

- **Project reference** is automatically extracted from `SUPABASE_URL`
- **Access token** must be added manually (get from dashboard)

## Security

✅ **Safe:** `env.json` is already in `.gitignore`
✅ **Safe:** Access tokens can be revoked/regenerated anytime
❌ **Never** commit access tokens to version control
❌ **Never** share access tokens publicly

## Troubleshooting

Run the config test first:
```bash
npx tsx test_config.ts
```

Common issues:
- **env.json not found** - Make sure you're in the project root
- **Access token not set** - Follow [ENV_SETUP.md](ENV_SETUP.md)
- **HTTP 401 error** - Token is invalid or expired, generate a new one
- **Templates not updating** - Wait 2-3 minutes and refresh dashboard

## Alternative: Manual Update

If scripts don't work, you can manually update:
1. Go to Supabase Dashboard
2. Navigate to **Authentication** → **Email Templates**
3. Copy/paste from [EMAIL_TEMPLATES.md](EMAIL_TEMPLATES.md)
4. Click **Save**

## Technical Details

- Uses [Supabase Management API](https://supabase.com/docs/reference/api)
- Endpoint: `PATCH /v1/projects/{ref}/config/auth`
- Updates `MAILER_SUBJECTS_*` and `MAILER_TEMPLATES_*` config keys
- Changes propagate through Supabase's internal systems (~2-3 minutes)

## Need Help?

See the detailed guides:
- [ENV_SETUP.md](ENV_SETUP.md) - Configuration setup
- [QUICK_START.md](QUICK_START.md) - Quick reference
- [UPDATE_EMAIL_TEMPLATES_README.md](UPDATE_EMAIL_TEMPLATES_README.md) - Full documentation
