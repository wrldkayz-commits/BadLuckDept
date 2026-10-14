function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char] ?? char)
}

// Customize the welcome email's copy, colors, layout, and dashboard button here.
export function welcomeEmailHtml(username: string, appUrl: string) {
  const greeting = escapeHtml(username)
  return `<!doctype html><html><body style="margin:0;background:#090909;color:#f4f4f4;font-family:Arial,sans-serif"><div style="max-width:560px;margin:36px auto;padding:32px 24px;background:#111;border:1px solid #2b2b2b;border-radius:12px"><p style="font-size:12px;letter-spacing:3px;color:#aaa">BADLUCKDEPT.</p><div style="height:1px;background:#333;margin:24px 0"></div><h1 style="font-size:28px;letter-spacing:-1px">Welcome, ${greeting}.</h1><p style="color:#c3c3c3;line-height:1.7">Your account is ready. Claim your corner of the internet, add your links, and make your page yours.</p><p style="margin:28px 0"><a href="${appUrl}/dashboard" style="display:inline-block;background:#f2f2f2;color:#090909;text-decoration:none;padding:13px 18px;border-radius:6px;font-weight:bold">Open your dashboard</a></p><p style="font-size:11px;line-height:1.6;color:#777">You received this message because you created a BadLuckDept account.</p></div></body></html>`
}
