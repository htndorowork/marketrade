# Push Notifications go-live checklist

The client side (subscribing, service worker, "Enable Notifications" button)
is already built and live in the app. Three things only you can do, because
they involve secrets and infrastructure outside this codebase:

## 1. Run the SQL
In Supabase SQL Editor for `spupfdclswjlpwiebwlq`, run:
- `push_notifications_migration.sql` (requires `security_hardening.sql` already applied)

Before running it, open the file and replace:
- `YOUR_PROJECT` → your actual project ref (`spupfdclswjlpwiebwlq`)
- `PUSH_SHARED_SECRET` → any random string you make up (e.g. a UUID) — this
  proves to the edge function that the call really came from your database.
  Use the **same string** in step 3 below.

## 2. Deploy the edge function
The function code is in `supabase-functions/send-push/index.ts` in this project
— copy it into your Supabase functions folder and deploy:
```bash
supabase functions deploy send-push --no-verify-jwt --project-ref spupfdclswjlpwiebwlq
```

## 3. Set the function's secrets
```bash
supabase secrets set \
  VAPID_PUBLIC_KEY=BMCQB-SziCpFZpfJ7VLwT4HmcXmqYs8JJ-t03A7Ra8MXsXeFmhIYGUIml5mZbNM2Ezzas1ZWl_k3qCA9gQR4YfY \
  VAPID_PRIVATE_KEY=KN55JXLksD0ouQmEG6bhNuJiVgNJk0MWulBA4o79e6E \
  VAPID_SUBJECT=mailto:studentmarketplacehelp@gmail.com \
  PUSH_SHARED_SECRET=<the same string you used in the SQL file> \
  --project-ref spupfdclswjlpwiebwlq
```

The VAPID key pair above was generated for you and is ready to use as-is.
**The private key must never appear in any HTML file** — it only goes in
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
