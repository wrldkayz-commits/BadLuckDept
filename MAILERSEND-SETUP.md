# BadLuckDept + MailerSend: quick setup

## A. Set up verification and password-reset emails

1. In Supabase, open **Authentication → URL Configuration**.
2. Set **Site URL** to your deployed website (for local testing: `http://localhost:5173`). Add both your local and deployed website URLs to **Redirect URLs**.
3. Keep email confirmation enabled under **Authentication → Providers → Email**.
4. In Supabase, open **Authentication → SMTP Settings** and enable custom SMTP.
5. In MailerSend, open the SMTP settings page and copy its SMTP host, port, username, and password. Paste those exact values into Supabase. Do not guess these values.
6. Set the sender/from address to an address on the domain you verified in MailerSend, for example `accounts@yourdomain.com`.
7. In Supabase **Authentication → Email Templates**, paste `supabase/email-templates/confirm-signup.html` into **Confirm signup**, and `supabase/email-templates/reset-password.html` into **Reset password**.

## B. Set up welcome emails

1. In MailerSend, create an API token with email-sending permission.
2. Install the Supabase CLI and open a terminal in this project folder.
3. Link your Supabase project:

   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   ```

4. Run `supabase/email-system.sql` in the Supabase SQL Editor.
5. Set server-side secrets (replace example values):

   ```bash
   supabase secrets set MAILERSEND_API_KEY=YOUR_MAILERSEND_API_TOKEN EMAIL_FROM=accounts@yourdomain.com EMAIL_FROM_NAME=BadLuckDept APP_URL=https://your-live-site.example
   ```

   `EMAIL_FROM` must be just the email address, not `Name <email>`.
6. Deploy the function:

   ```bash
   supabase functions deploy send-welcome
   ```

## C. Test

1. Sign up using an inbox you can access and click the verification email.
2. Log in. The welcome email should be sent once to the verified account email.
3. Log out and use **Forgot your password?** to test the reset email.
4. If anything fails, check Supabase **Edge Functions → send-welcome → Logs** and MailerSend activity. Never put the MailerSend API token or Supabase service-role key in a `VITE_` variable, frontend file, or public repository.

## Important

Supabase sends verification and password-reset emails through SMTP; the `send-welcome` function uses MailerSend's HTTPS API. Those are two separate configurations, so configure both. MailerSend's available limits and SMTP/API permissions depend on your account plan.
