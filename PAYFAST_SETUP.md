# PayFast go-live checklist (accurate as of this build)

Your Supabase project ref is **`spupfdclswjlpwiebwlq`** — use that in every
command below (older notes in this repo referenced a different project;
that was a mistake in the docs, not a second real project).

## 1. Run the SQL
In the Supabase SQL Editor for `spupfdclswjlpwiebwlq`, run, in order:
1. `setup.sql` (if you haven't already — this already includes the
   PayFast `subscription_payments` table and the security hardening;
   those used to be separate files but are now merged into this one)
2. `new_features_migration.sql`
3. `bugfixes_and_restock_migration.sql`

## 2. PayFast secrets (server only — never in HTML)
```bash
supabase secrets set \
  PAYFAST_MERCHANT_ID=your_id \
  PAYFAST_MERCHANT_KEY=your_key \
  PAYFAST_PASSPHRASE=your_passphrase \
  PAYFAST_SANDBOX=true \
  --project-ref spupfdclswjlpwiebwlq
```
Get these three values from your PayFast merchant dashboard (Settings →
Integration). Leave `PAYFAST_SANDBOX=true` until you've tested a full
payment end-to-end with PayFast's sandbox card, then set it to `false`
to go live.

## 3. Deploy the edge functions
```bash
supabase functions deploy payfast-checkout --project-ref spupfdclswjlpwiebwlq
supabase functions deploy payfast-itn --no-verify-jwt --project-ref spupfdclswjlpwiebwlq
```
- `payfast-checkout` — called by seller.html when a seller picks a plan.
  Requires the seller to be signed in (JWT verified automatically).
- `payfast-itn` — PayFast's server calls this directly after a payment.
  Must be deployed with `--no-verify-jwt` since PayFast can't send a
  Supabase JWT. Its URL is built automatically by payfast-checkout as
  the `notify_url`, so there's nothing to configure on PayFast's side.

Both functions live in `supabase-functions/payfast-checkout/` and
`supabase-functions/payfast-itn/` in this repo.

## 4. Test it
1. With `PAYFAST_SANDBOX=true`, go to Seller Dashboard → Change Plan →
   pick any plan → you should be redirected to PayFast's sandbox
   checkout.
2. Pay with a PayFast sandbox test card (see PayFast's sandbox docs for
   current test card numbers).
3. You should land on `payment-return.html`, and within a few seconds
   your seller plan should show as active (refresh Seller Dashboard).
4. Check the `subscription_payments` table in Supabase — the row should
   flip from `pending` to `completed`.
5. If it doesn't update: check the `payfast-itn` function logs in the
   Supabase dashboard (Edge Functions → payfast-itn → Logs) for the
   specific error.

## 5. Go live
Once a sandbox payment works end-to-end:
```bash
supabase secrets set PAYFAST_SANDBOX=false --project-ref spupfdclswjlpwiebwlq
```
Then switch your PayFast merchant credentials from sandbox to your real
merchant ID/key if you were using PayFast's sandbox merchant account.

## Admin fallback
If a payment succeeds on PayFast's side but somehow doesn't reflect in
Marketrade (rare — e.g. a webhook delivery failure), an admin can always
manually activate a seller's plan from Admin → Users using the **+30d /
+7d** buttons, or via `admin_extend_subscription`.
