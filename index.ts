
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { welcomeEmailHtml } from './welcome-template.ts'

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  headers: Record<string, string> = {},
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...headers,
      'Content-Type': 'application/json',
    },
  })
}

function corsHeadersFor(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') ?? ''
  const appUrl = (Deno.env.get('APP_URL') ?? '').replace(/\/$/, '')

  const isLocalDev =
    /^http:\/\/(localhost|127\.0\.0\.1):5173$/.test(origin)

  const allowedOrigin =
    origin && (origin === appUrl || isLocalDev) ? origin : appUrl

  return {
    'Access-Control-Allow-Origin': allowedOrigin || 'null',
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

Deno.serve(async (request: Request) => {
  const corsHeaders = corsHeadersFor(request)

  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return jsonResponse(
      { error: 'Method not allowed.' },
      405,
      { ...corsHeaders, Allow: 'POST, OPTIONS' },
    )
  }

  const authorization = request.headers.get('Authorization')

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const mailerSendKey = Deno.env.get('MAILERSEND_API_KEY')
  const from = Deno.env.get('EMAIL_FROM')
  const appUrl = (Deno.env.get('APP_URL') ?? '').replace(/\/$/, '')
  const fromName = Deno.env.get('EMAIL_FROM_NAME') ?? 'BadLuckDept'

  if (
    !supabaseUrl ||
    !anonKey ||
    !serviceRoleKey ||
    !mailerSendKey ||
    !from ||
    !appUrl
  ) {
    return jsonResponse(
      { error: 'Email service is not fully configured. Check Edge Function secrets.' },
      500,
      corsHeaders,
    )
  }

  if (!authorization?.startsWith('Bearer ')) {
    return jsonResponse(
      { error: 'Authentication required.' },
      401,
      corsHeaders,
    )
  }

  // Verify the caller using their Supabase access token.
  const callerClient = createClient(supabaseUrl, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    global: {
      headers: { Authorization: authorization },
    },
  })

  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser()

  if (userError || !user) {
    return jsonResponse(
      { error: 'Your session is invalid or expired. Please sign in again.' },
      401,
      corsHeaders,
    )
  }

  if (!user.email || !user.email_confirmed_at) {
    return jsonResponse(
      { error: 'Confirm your email before receiving the welcome message.' },
      403,
      corsHeaders,
    )
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  })

  // Reserve the welcome event. The database should enforce uniqueness
  // on (user_id, event_type) to prevent duplicate welcome messages.
  const { error: reserveError } = await admin
    .from('email_events')
    .insert({
      user_id: user.id,
      event_type: 'welcome',
    })

  if (reserveError?.code === '23505') {
    return jsonResponse(
      { ok: true, alreadySent: true },
      200,
      corsHeaders,
    )
  }

  if (reserveError) {
    console.error('Could not reserve welcome email:', reserveError.code)

    return jsonResponse(
      { error: 'Could not reserve welcome email. Check the email_events table and its constraints.' },
      500,
      corsHeaders,
    )
  }

  const rawUsername = user.user_metadata?.username
  const username =
    typeof rawUsername === 'string' && rawUsername.trim()
      ? rawUsername.trim()
      : 'there'

  try {
    const html = welcomeEmailHtml(username, appUrl)

    const response = await fetch('https://api.mailersend.com/v1/email', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${mailerSendKey}`,
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: JSON.stringify({
        from: {
          email: from,
          name: fromName,
        },
        to: [
          {
            email: user.email,
            name: username,
          },
        ],
        subject: 'Welcome to BadLuckDept',
        html,
        text: `Welcome to BadLuckDept, ${username}. Open your dashboard: ${appUrl}/dashboard`,
      }),
    })

    if (!response.ok) {
      // Log only the provider status, never the API token.
      console.error('MailerSend rejected welcome email. HTTP status:', response.status)

      // Release the reservation so a later attempt can retry.
      const { error: cleanupError } = await admin
        .from('email_events')
        .delete()
        .eq('user_id', user.id)
        .eq('event_type', 'welcome')

      if (cleanupError) {
        console.error('Could not release email reservation:', cleanupError.code)
      }

      return jsonResponse(
        {
          error: 'MailerSend rejected the welcome message.',
          providerStatus: response.status,
        },
        502,
        corsHeaders,
      )
    }

    return jsonResponse({ ok: true }, 200, corsHeaders)
  } catch (error) {
    console.error(
      'Welcome email request failed:',
      error instanceof Error ? error.message : 'Unknown error',
    )

    const { error: cleanupError } = await admin
      .from('email_events')
      .delete()
      .eq('user_id', user.id)
      .eq('event_type', 'welcome')

    if (cleanupError) {
      console.error('Could not release email reservation:', cleanupError.code)
    }

    return jsonResponse(
      { error: 'Could not generate or send the welcome email.' },
      502,
      corsHeaders,
    )
  }
})
