# Supabase Email Templates for Poker Manager Beta

Configure these email templates in your Supabase Dashboard:
**Dashboard > Authentication > Email Templates**

---

## 1. Confirm Signup

**Subject:**
```
Welcome to Poker Manager Beta - Confirm Your Email
```

**Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">

    <!-- Header -->
    <div style="background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 50%, #1B5E20 100%); padding: 40px 20px; text-align: center;">
      <div style="display: inline-block; background-color: #ffffff; border-radius: 50%; padding: 15px; margin-bottom: 15px;">
        <span style="font-size: 40px;">&#9824;</span>
      </div>
      <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Poker Manager</h1>
      <span style="display: inline-block; background: linear-gradient(135deg, #FF6B00, #FF9800); color: #ffffff; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 8px;">BETA</span>
    </div>

    <!-- Content -->
    <div style="padding: 40px 30px;">
      <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">Welcome to Poker Manager!</h2>

      <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
        Thank you for joining our beta program! You're one step away from organizing poker nights, tracking your games, and settling up with friends.
      </p>

      <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
        Please confirm your email address to get started:
      </p>

      <!-- CTA Button -->
      <div style="text-align: center; margin: 30px 0;">
        <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: linear-gradient(135deg, #2E7D32, #4CAF50); color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);">
          Confirm Email Address
        </a>
      </div>

      <!-- Features -->
      <div style="background-color: #f8f9fa; border-radius: 8px; padding: 20px; margin: 30px 0;">
        <p style="color: #333333; font-size: 14px; font-weight: 600; margin: 0 0 15px 0;">What you can do with Poker Manager:</p>
        <ul style="color: #666666; font-size: 14px; line-height: 1.8; margin: 0; padding-left: 20px;">
          <li>Create and manage poker groups</li>
          <li>Track buy-ins and cash-outs in real-time</li>
          <li>View detailed game statistics</li>
          <li>Settle up with other players effortlessly</li>
        </ul>
      </div>

      <p style="color: #999999; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
        If you didn't create an account with Poker Manager, you can safely ignore this email.
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #eeeeee;">
      <p style="color: #999999; font-size: 12px; margin: 0;">
        &copy; 2026 Poker Manager Team<br>
        Your Game, Your Way
      </p>
    </div>

  </div>
</body>
</html>
```

---

## 2. Reset Password

**Subject:**
```
Poker Manager Beta - Reset Your Password
```

**Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">

    <!-- Header -->
    <div style="background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 50%, #1B5E20 100%); padding: 40px 20px; text-align: center;">
      <div style="display: inline-block; background-color: #ffffff; border-radius: 50%; padding: 15px; margin-bottom: 15px;">
        <span style="font-size: 40px;">&#9824;</span>
      </div>
      <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Poker Manager</h1>
      <span style="display: inline-block; background: linear-gradient(135deg, #FF6B00, #FF9800); color: #ffffff; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 8px;">BETA</span>
    </div>

    <!-- Content -->
    <div style="padding: 40px 30px;">
      <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">Reset Your Password</h2>

      <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
        We received a request to reset your password. Click the button below to create a new password:
      </p>

      <!-- CTA Button -->
      <div style="text-align: center; margin: 30px 0;">
        <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: linear-gradient(135deg, #2E7D32, #4CAF50); color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);">
          Reset Password
        </a>
      </div>

      <p style="color: #999999; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
        If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.
      </p>

      <p style="color: #999999; font-size: 14px; line-height: 1.6; margin: 10px 0 0 0;">
        This link will expire in 24 hours for security reasons.
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #eeeeee;">
      <p style="color: #999999; font-size: 12px; margin: 0;">
        &copy; 2026 Poker Manager Team<br>
        Your Game, Your Way
      </p>
    </div>

  </div>
</body>
</html>
```

---

## 3. Magic Link (if enabled)

**Subject:**
```
Poker Manager Beta - Your Sign In Link
```

**Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">

    <!-- Header -->
    <div style="background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 50%, #1B5E20 100%); padding: 40px 20px; text-align: center;">
      <div style="display: inline-block; background-color: #ffffff; border-radius: 50%; padding: 15px; margin-bottom: 15px;">
        <span style="font-size: 40px;">&#9824;</span>
      </div>
      <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Poker Manager</h1>
      <span style="display: inline-block; background: linear-gradient(135deg, #FF6B00, #FF9800); color: #ffffff; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 8px;">BETA</span>
    </div>

    <!-- Content -->
    <div style="padding: 40px 30px;">
      <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">Sign In to Poker Manager</h2>

      <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
        Click the button below to sign in to your account:
      </p>

      <!-- CTA Button -->
      <div style="text-align: center; margin: 30px 0;">
        <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: linear-gradient(135deg, #2E7D32, #4CAF50); color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);">
          Sign In
        </a>
      </div>

      <p style="color: #999999; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
        If you didn't request this link, you can safely ignore this email.
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #eeeeee;">
      <p style="color: #999999; font-size: 12px; margin: 0;">
        &copy; 2026 Poker Manager Team<br>
        Your Game, Your Way
      </p>
    </div>

  </div>
</body>
</html>
```

---

## 4. Invite User (for group invitations)

**Subject:**
```
You've been invited to join a poker group on Poker Manager Beta
```

**Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">

    <!-- Header -->
    <div style="background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 50%, #1B5E20 100%); padding: 40px 20px; text-align: center;">
      <div style="display: inline-block; background-color: #ffffff; border-radius: 50%; padding: 15px; margin-bottom: 15px;">
        <span style="font-size: 40px;">&#9824;</span>
      </div>
      <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Poker Manager</h1>
      <span style="display: inline-block; background: linear-gradient(135deg, #FF6B00, #FF9800); color: #ffffff; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 8px;">BETA</span>
    </div>

    <!-- Content -->
    <div style="padding: 40px 30px;">
      <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">You're Invited!</h2>

      <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
        You've been invited to join a poker group on Poker Manager. Click the button below to accept the invitation and join the action:
      </p>

      <!-- CTA Button -->
      <div style="text-align: center; margin: 30px 0;">
        <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: linear-gradient(135deg, #2E7D32, #4CAF50); color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);">
          Accept Invitation
        </a>
      </div>

      <!-- Features -->
      <div style="background-color: #f8f9fa; border-radius: 8px; padding: 20px; margin: 30px 0;">
        <p style="color: #333333; font-size: 14px; font-weight: 600; margin: 0 0 15px 0;">With Poker Manager you can:</p>
        <ul style="color: #666666; font-size: 14px; line-height: 1.8; margin: 0; padding-left: 20px;">
          <li>Join poker games with your group</li>
          <li>Track buy-ins and cash-outs</li>
          <li>View your statistics and history</li>
          <li>Settle up with other players</li>
        </ul>
      </div>

      <p style="color: #999999; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
        If you don't know the person who invited you, you can safely ignore this email.
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #eeeeee;">
      <p style="color: #999999; font-size: 12px; margin: 0;">
        &copy; 2026 Poker Manager Team<br>
        Your Game, Your Way
      </p>
    </div>

  </div>
</body>
</html>
```

---

## How to Configure

1. Go to your **Supabase Dashboard**
2. Navigate to **Authentication** > **Email Templates**
3. For each template type (Confirm signup, Reset password, Magic link, Invite user):
   - Copy the **Subject** line
   - Copy the **HTML Body** content
   - Click **Save**

4. To change the sender name from "Supabase Auth":
   - Go to **Project Settings** > **Authentication**
   - Under **SMTP Settings**, you can either:
     - Configure a custom SMTP server (recommended for production)
     - Or the emails will come from Supabase's default sender

5. For a custom sender name without custom SMTP:
   - This requires a paid Supabase plan with custom SMTP configuration
   - You can use services like SendGrid, Mailgun, or AWS SES

---

## Note on {{ .ConfirmationURL }}

The `{{ .ConfirmationURL }}` is a Supabase template variable that will be automatically replaced with the actual confirmation URL when the email is sent.
