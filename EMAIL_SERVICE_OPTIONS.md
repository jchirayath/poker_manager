# Email Service Options for RSVP Feature

## Overview

The RSVP feature requires sending transactional emails with custom HTML content and magic links. Supabase's built-in email service only handles **auth-related emails** (signup, password reset, invites), so we need an external email service for custom RSVP emails.

## Recommended: Resend (Free Tier)

**Why Resend?**
- ✅ **Generous free tier**: 3,000 emails/month, 100 emails/day
- ✅ **Simple API**: One HTTP POST request
- ✅ **Fast setup**: 5 minutes to get started
- ✅ **Reliable delivery**: High deliverability rates
- ✅ **No credit card required** for free tier
- ✅ **Great for small-medium groups**

### Setup Instructions

1. **Sign up at [resend.com](https://resend.com)**
   - Create free account (no credit card needed)

2. **Get API Key**
   - Go to API Keys section
   - Click "Create API Key"
   - Copy the key (starts with `re_`)

3. **Set Supabase Secret**
   ```bash
   cd /Users/jacobc/code/poker_manager
   supabase secrets set RESEND_API_KEY=re_your_api_key_here
   ```

4. **Update "From" Address** (Optional - for custom domain)

   **Default** (works immediately):
   ```typescript
   from: "Poker Manager <onboarding@resend.dev>"
   ```

   **Custom Domain** (better deliverability):
   - Add your domain in Resend dashboard
   - Verify DNS records
   - Update in [send-rsvp-emails/index.ts:259](supabase/functions/send-rsvp-emails/index.ts#L259):
     ```typescript
     from: "Poker Manager <noreply@yourdomain.com>"
     ```

5. **Deploy Function**
   ```bash
   supabase functions deploy send-rsvp-emails
   ```

6. **Test**
   - Create a game in the app
   - Check if email arrives
   - Click RSVP button to verify magic link works

### Free Tier Limits
- **3,000 emails/month** - Good for ~100 games/month with 30 players each
- **100 emails/day** - Sufficient for most use cases
- If exceeded, emails queue until next day (or upgrade to paid plan)

## Alternative: SendGrid (Free Tier)

If you prefer SendGrid:

**Free Tier**: 100 emails/day forever

**Setup**:
1. Sign up at [sendgrid.com](https://sendgrid.com)
2. Get API key
3. Update function to use SendGrid API:

```typescript
const emailRes = await fetch("https://api.sendgrid.com/v3/mail/send", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${sendgridApiKey}`,
  },
  body: JSON.stringify({
    personalizations: [{
      to: [{ email: profile.email }],
      subject: `RSVP: ${game.name} - ${formattedDate}`,
    }],
    from: { email: "noreply@yourdomain.com", name: "Poker Manager" },
    content: [{ type: "text/html", value: emailHtml }],
  }),
});
```

## Alternative: AWS SES (Pay-as-you-go)

For larger scale or if you already use AWS:

**Pricing**: $0.10 per 1,000 emails (very cheap at scale)

**Setup**:
1. Enable AWS SES in your region
2. Verify domain
3. Request production access (initially in sandbox)
4. Use AWS SDK in Supabase Function

**Pros**: Extremely cheap, unlimited scale
**Cons**: More complex setup, requires AWS account

## Alternative: Mailgun (Free Tier)

**Free Tier**: 5,000 emails/month for first 3 months, then pay-as-you-go

Similar setup to Resend/SendGrid.

## Alternative: SMTP Server

If you have your own SMTP server:

**Setup**:
```typescript
// Use Deno's SMTP client
import { SmtpClient } from "https://deno.land/x/smtp/mod.ts";

const client = new SmtpClient();
await client.connectTLS({
  hostname: "smtp.yourdomain.com",
  port: 465,
  username: "your-email@yourdomain.com",
  password: "your-password",
});

await client.send({
  from: "noreply@yourdomain.com",
  to: profile.email,
  subject: `RSVP: ${game.name} - ${formattedDate}`,
  content: emailHtml,
  html: emailHtml,
});

await client.close();
```

**Pros**: Full control, no third-party dependency
**Cons**: Deliverability issues, spam filters, maintenance overhead

## Comparison Table

| Service | Free Tier | Monthly Cost | Setup Time | Deliverability | Recommended For |
|---------|-----------|--------------|------------|----------------|-----------------|
| **Resend** | 3,000/mo | $0 (then $20) | 5 min | Excellent | **Most users** ✅ |
| SendGrid | 100/day | $0 forever | 10 min | Good | Small groups |
| AWS SES | None | $0.10/1000 | 30 min | Excellent | Large scale |
| Mailgun | 5,000/mo* | $15 after trial | 10 min | Good | Medium groups |
| SMTP | Unlimited | Varies | 1+ hour | Poor-Fair | Self-hosted |

\* Free for first 3 months only

## Current Implementation

The RSVP feature currently uses **Resend** in [send-rsvp-emails/index.ts:252](supabase/functions/send-rsvp-emails/index.ts#L252).

To switch to a different provider, update the email sending code in that file.

## Can I Use Supabase's Email Service?

**Short answer: No, not for RSVP emails.**

**Why?**
- Supabase's built-in email is **only for auth emails**: signup, password reset, magic links, user invites
- It uses fixed templates defined in Supabase Dashboard > Authentication > Email Templates
- You cannot send custom HTML emails with arbitrary content
- RSVP emails require custom HTML with game details and magic links

**What Supabase Email DOES Support:**
- User signup confirmation
- Password reset emails
- Magic link login
- User invitations (via `auth.admin.inviteUserByEmail()`)

**What you're already using Supabase email for:**
- The existing `invite-user` function uses `auth.admin.inviteUserByEmail()` ✅
- This is perfect for inviting new users to the app

**What requires an external service:**
- RSVP invitations with game details
- Email reminders
- Custom notifications
- Any transactional email with dynamic content

## Recommendation Summary

**For most users**: Stick with **Resend** (current implementation)
- Free for typical usage (3,000 emails/month)
- Super simple setup
- Excellent deliverability
- No credit card required

**For power users with 100+ games/month**: Consider **AWS SES**
- More cost effective at scale
- Requires more technical setup

**For developers**: Resend's API is the easiest to work with and has great documentation.
