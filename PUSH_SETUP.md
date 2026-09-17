# Push Notifications go-live checklist

The client side (subscribing, service worker, "Enable Notifications" button)
is already built and live in the app. Three things only you can do, because
they involve secrets and infrastructure outside this codebase:

## 1. Run the SQL
In Supabase SQL Editor for `kqsqtasykdtpdrkqyaxp`, run:
- `push_notifications_migration.sql` (requires `security_hardening.sql` already applied)

Before running it, open the file and replace:
- `YOUR_PROJECT` → your actual project ref (`kqsqtasykdtpdrkqyaxp`)
- `PUSH_SHARED_SECRET` → any random string you make up (e.g. a UUID) — this
  proves to the edge function that the call really came from your database.
  Use the **same string** in step 3 below.

## 2. Deploy the edge function
The function code is in `supabase-functions/send-push/index.ts` in this project
— copy it into your Supabase functions folder and deploy:
```bash
supabase functions deploy send-push --no-verify-jwt --project-ref kqsqtasykdtpdrkqyaxp
```

## 3. Set the function's secrets
```bash
supabase secrets set \
  VAPID_PUBLIC_KEY=BDyOj8uuDSlLJDGHXjMZYWWvELnV2jtbQ5YY93jxZ_TNYAcDLgUUaaOntRyt-iOWUvEV-aIZbBIfCrLEQ_fxnD4 \
  VAPID_PRIVATE_KEY=<your private key — see below, NEVER commit the real value to git> \
  VAPID_SUBJECT=mailto:studentmarketplacehelp@gmail.com \
  PUSH_SHARED_SECRET=<the same string you used in the SQL file> \
  --project-ref kqsqtasykdtpdrkqyaxp
```

**Where to get the private key:** it's yours alone and only you have it — it
was shown to you once when this key pair was generated and is intentionally
NOT written down anywhere in this repo (an earlier version of this file did
include it in plain text, which is a real secret leak if that file was ever
pushed to a public or even private GitHub repo — treat that old key as
compromised; it's why this is now a brand-new key pair). If you've lost your
copy of the private key, generate a completely new pair (see below) rather
than trying to recover the old one, and update BOTH this secret and
`VAPID_PUBLIC_KEY` in `seller.html`/`profile.html` together — a mismatched
pair breaks push notifications entirely.

To generate a new pair yourself at any time:
```bash
npx web-push generate-vapid-keys
```

This is a brand-new, unique key pair generated specifically for this project
(the previous key pair was a shared/template value and has been replaced
everywhere — frontend and these instructions both updated together, so there's
no mismatch between what the browser sends and what the edge function signs
with).
**The private key must never appear in any HTML file, this file, or any file
committed to git** — it only goes in
this secrets command, never in the frontend. The public key is already
embedded in the frontend (`index.html`, `seller.html`, `profile.html`)
where users subscribe.

## What you get once this is live
- New message → the recipient gets a push, even if the tab/app is closed.
- New order → the seller gets a push.
- Order marked complete → the buyer gets a push (nudging them to leave a review).
- Price drop / back in stock on a favorited item → still works as before, now also pushed.

## Testing
1. Complete steps 1–3 above.
2. Open the site on your phone, sign in, go to **Profile → Security** (or
   **Seller Dashboard → Security**) and tap **"🔔 Enable Push Notifications."**
   Accept the browser permission prompt.
3. From a second account, message yourself or place a test order — a real
   notification should appear even with the browser closed.

## Notes
- iOS requires the site to be **installed to the Home Screen first** (Safari
  Share → Add to Home Screen) before push permission can even be requested —
  this is an Apple platform restriction, not something in our control.
- If you ever rotate the VAPID keys, update BOTH: the secret on the edge
  function AND the `VAPID_PUBLIC_KEY` constant in the three HTML files —
  otherwise existing subscriptions silently stop working.
