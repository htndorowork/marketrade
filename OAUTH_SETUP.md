# Google & Apple sign-in — setup checklist

The buttons are live in `login.html` (both Sign In and Sign Up), but each
provider needs to be turned on in Supabase before they'll work — otherwise
clicking them returns an "Unsupported provider" error.

## 1. Google
1. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials),
   create an OAuth Client ID (Web application).
2. Authorized redirect URI:
   `https://spupfdclswjlpwiebwlq.supabase.co/auth/v1/callback`
3. Supabase Dashboard → Authentication → Providers → **Google** → paste the
   Client ID and Client Secret → Save.

## 2. Apple
1. In the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list/serviceId),
   create a Services ID and a Sign in with Apple key.
2. Redirect URL (same for every project): `https://spupfdclswjlpwiebwlq.supabase.co/auth/v1/callback`
3. Supabase Dashboard → Authentication → Providers → **Apple** → fill in the
   Services ID, Team ID, Key ID, and private key → Save.

## 3. Allowed redirect URLs
Supabase Dashboard → Authentication → URL Configuration → add
`https://www.marketrade.co/oauth-callback` (and your local/staging equivalent)
to **Redirect URLs**, or the OAuth flow will bounce back with an error
instead of landing on `oauth-callback.html`.

## How it behaves in the app
- Both providers route through `oauth-callback.html` after the person
  approves the sign-in on Google's/Apple's own page.
- Supabase's existing `handle_new_user` trigger creates a blank profile row
  the same way it already does for email/password sign-ups.
- Since Google/Apple never hand over a WhatsApp number, `oauth-callback.html`
  checks whether `full_name`/`whatsapp` are still empty and, if so, sends the
  person to `profile.html?complete=1`, which jumps straight to the Edit tab
  with a short "welcome, finish setting up" banner. Once saved, they land on
  their normal dashboard from then on — no different from an email/password
  account.
