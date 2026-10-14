# BadLuckDept email templates

Paste `confirm-signup.html` into Supabase **Authentication → Email Templates → Confirm signup** and `reset-password.html` into **Reset password**. Keep the `{{ .TokenHash }}` variables and the `type=email` / `type=recovery` values intact.

These links route through the site's `/auth/confirm` page. Set Supabase **Authentication → URL Configuration → Site URL** to your deployed site URL and add your local and production URLs to the allowed redirect URLs.

Supabase Auth sends verification and password-reset messages through your configured SMTP provider. Use the SMTP hostname, port, username, and password displayed by MailerSend. Set the sender address to an address on your verified MailerSend domain.

Welcome emails are sent by the `send-welcome` Supabase Edge Function through the MailerSend API. Configure `MAILERSEND_API_KEY`, `EMAIL_FROM`, `EMAIL_FROM_NAME`, and `APP_URL` as Supabase Edge Function secrets. Never put the MailerSend API token in frontend code or a `VITE_` variable.
