# RSVP Feature - Quick Start Guide

Get the RSVP feature running in **under 10 minutes**!

## Prerequisites
- Poker Manager app already set up with Supabase
- Supabase CLI installed (`brew install supabase/tap/supabase`)

## Step 1: Run Database Migration (2 minutes)

```bash
cd /Users/jacobc/code/poker_manager

# Push migration to create RSVP tables
supabase db push
```

This creates:
- `rsvp_tokens` table for magic links
- `auto_send_rsvp_emails` column in `groups` table

## Step 2: Set Up Resend Email Service (5 minutes)

### 2a. Create Resend Account
1. Go to [resend.com](https://resend.com)
2. Click "Start Building" or "Sign Up"
3. Sign up with email (no credit card needed)
4. Verify your email

### 2b. Get API Key
1. Once logged in, go to "API Keys" in left sidebar
2. Click "Create API Key"
3. Name it: `Poker Manager RSVP`
4. Copy the key (starts with `re_`)

### 2c. Set Supabase Secret
```bash
# Replace re_xxx with your actual key
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxxxxxxx
```

Verify it's set:
```bash
supabase secrets list
```

You should see `RESEND_API_KEY` in the list.

## Step 3: Deploy Supabase Functions (2 minutes)

```bash
# Deploy the email sending function
supabase functions deploy send-rsvp-emails

# Deploy the magic link handler
supabase functions deploy handle-rsvp
```

## Step 4: Test the Feature (1 minute)

### In the App:
1. Open the app and go to a group
2. Create a new game with at least one other player
3. Check your email - you should receive an RSVP invitation
4. Click one of the buttons (👍 Going / 👌 Maybe / 👎 Can't Make It)
5. Verify the browser shows a confirmation page
6. Go back to the app and check the game detail screen
7. You should see your RSVP status updated!

### Troubleshooting
If emails don't arrive:
1. Check spam folder
2. Verify Resend API key: `supabase secrets list`
3. Check function logs:
   ```bash
   supabase functions logs send-rsvp-emails
   ```
4. Verify email was sent in Resend dashboard (Logs section)

## Step 5: Optional - Custom Email Domain

**Note**: You can skip this and use `onboarding@resend.dev` for testing. It works fine!

For a professional look with your own domain:

1. **Add Domain in Resend**
   - Go to Resend dashboard > Domains
   - Click "Add Domain"
   - Enter your domain (e.g., `yourdomain.com`)

2. **Add DNS Records**
   - Copy the DNS records Resend provides
   - Add them to your domain's DNS settings
   - Wait for verification (can take up to 48 hours)

3. **Update Function**
   Edit `supabase/functions/send-rsvp-emails/index.ts` line 259:
   ```typescript
   from: "Poker Manager <noreply@yourdomain.com>",
   ```

4. **Redeploy**
   ```bash
   supabase functions deploy send-rsvp-emails
   ```

## Usage

### Auto-Send on Game Creation (Default)
When you create a game, RSVP emails are sent automatically to all group members.

To disable for a specific group:
```sql
UPDATE groups
SET auto_send_rsvp_emails = false
WHERE id = 'your-group-id';
```

### Manual Send from Game Detail Screen
1. Open any scheduled game
2. Scroll to "RSVP Summary" card
3. Click "Send Invites" button (admin only)
4. Confirm

### Players Can RSVP Via:
1. **Email Magic Link** - Click button in email (no login required)
2. **In-App** - Tap their RSVP status in game detail screen

## Features at a Glance

✅ **Email Invitations** - Beautiful HTML emails with game details
✅ **One-Click RSVP** - No login required via magic links
✅ **In-App Updates** - Change RSVP anytime in the app
✅ **Visual Indicators** - 👍/👌/👎 icons with colors
✅ **RSVP Summary** - See counts (Going/Maybe/Not Going)
✅ **Admin Controls** - Manual email trigger, auto-send setting
✅ **Auto-Add Participants** - Players who RSVP "Going" are added to game

## Cost

**Free Tier (Resend):**
- 3,000 emails per month
- 100 emails per day
- No credit card required

**Example Usage:**
- 10 players per game
- 30 games per month
- = 300 emails/month (well within free tier!)

**If you exceed limits:**
- Upgrade to paid plan: $20/month for 50,000 emails
- Or switch to AWS SES (see EMAIL_SERVICE_OPTIONS.md)

## What's Next?

### Enable Group Settings UI (Future Enhancement)
Add a toggle in group settings screen to control `auto_send_rsvp_emails`.

### WhatsApp Integration (Planned)
See [RSVP_FEATURE.md](RSVP_FEATURE.md#whatsapp-integration) for roadmap.

### Email Reminders (Future)
Send automatic reminders 24 hours before game starts.

## Support

**Documentation:**
- [RSVP_FEATURE.md](RSVP_FEATURE.md) - Complete technical documentation
- [EMAIL_SERVICE_OPTIONS.md](EMAIL_SERVICE_OPTIONS.md) - Email provider comparison

**Troubleshooting:**
See the Troubleshooting section in [RSVP_FEATURE.md](RSVP_FEATURE.md#troubleshooting)

**Questions?**
Check function logs:
```bash
# Email sending logs
supabase functions logs send-rsvp-emails --tail

# Magic link processing logs
supabase functions logs handle-rsvp --tail
```

---

**That's it! You're ready to use RSVP! 🎉**
