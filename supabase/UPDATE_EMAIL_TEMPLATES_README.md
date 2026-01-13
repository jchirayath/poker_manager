# Email Templates Management

This directory contains scripts to programmatically update Supabase email templates from [EMAIL_TEMPLATES.md](./EMAIL_TEMPLATES.md).

## Prerequisites

1. **Supabase Access Token**
   - Go to https://supabase.com/dashboard/account/tokens
   - Create a new access token with the necessary permissions
   - Add it to your `env.json` file in the project root

2. **env.json Configuration**
   - The scripts read configuration from `env.json` in the project root
   - Your project reference is automatically extracted from `SUPABASE_URL`
   - You only need to add `SUPABASE_ACCESS_TOKEN` to the file

## Method 1: Using TypeScript/Node.js (Recommended)

### Setup

1. **Install tsx if you don't have it:**
   ```bash
   npm install -g tsx
   ```

2. **Add your access token to env.json:**
   ```json
   {
     "SUPABASE_URL": "https://your-project.supabase.co",
     "SUPABASE_ANON_KEY": "...",
     "SUPABASE_SERVICE_ROLE_KEY": "...",
     "SUPABASE_DB_URL": "...",
     "SUPABASE_ACCESS_TOKEN": "sbp_your_access_token_here"
   }
   ```

### Usage

```bash
# Simply run the script - it reads from env.json automatically
npx tsx supabase/update_email_templates.ts
```

Or from the supabase directory:

```bash
cd supabase
npx tsx update_email_templates.ts
```

## Method 2: Using Bash Script

### Setup

1. **Make the script executable:**
   ```bash
   chmod +x supabase/update_email_templates.sh
   ```

2. **Install jq (JSON processor):**
   ```bash
   # Install on macOS
   brew install jq

   # Install on Ubuntu/Debian
   sudo apt-get install jq
   ```

3. **Add your access token to env.json** (same as Method 1)

### Usage

```bash
# Run the script - it reads from env.json automatically
./supabase/update_email_templates.sh
```

## Updating Templates

1. Edit the templates in [EMAIL_TEMPLATES.md](./EMAIL_TEMPLATES.md)
2. Run one of the update scripts above
3. Wait a few minutes for changes to propagate
4. Test the templates by triggering the corresponding auth flows

## Template Types

The scripts update these four email template types:

1. **Confirm Signup** - Sent when users sign up
2. **Reset Password** - Sent when users request password reset
3. **Magic Link** - Sent for passwordless authentication (if enabled)
4. **Invite User** - Sent when inviting users to groups

## Troubleshooting

### "SUPABASE_ACCESS_TOKEN is not set in env.json"
Add your access token to `env.json` in the project root:
```json
{
  "SUPABASE_ACCESS_TOKEN": "sbp_your_token_here"
}
```

### "env.json file not found"
Make sure `env.json` exists in the project root directory (one level up from the supabase folder).

### "HTTP 401" error
Your access token may be invalid or expired. Generate a new one from the dashboard.

### "HTTP 403" error
Your access token doesn't have the necessary permissions. Make sure it has access to modify project settings.

### Template not updating
- Check that the template name in EMAIL_TEMPLATES.md exactly matches the expected format
- Wait a few minutes after running the script
- Check the Supabase dashboard to verify the changes

## Manual Alternative

If the scripts don't work, you can always update templates manually:

1. Go to your **Supabase Dashboard**
2. Navigate to **Authentication** > **Email Templates**
3. Copy the subject and body from [EMAIL_TEMPLATES.md](./EMAIL_TEMPLATES.md)
4. Paste into the corresponding template fields
5. Click **Save**

## Security Notes

- **Never commit** your access token to version control
- Add `.env` to your `.gitignore`
- Rotate access tokens regularly
- Use tokens with minimal required permissions
