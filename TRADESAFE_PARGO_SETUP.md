# TradeSafe escrow + Pargo delivery — go-live checklist

Your Supabase project ref is **`spupfdclswjlpwiebwlq`** — use that in every
command below. This adds a *second, optional* way for a buyer to pay a
seller (real online payment, held in escrow) alongside the existing
"arrange privately" flow, which is untouched and stays the default.

## 0. Read this first — what's verified vs. what isn't

- **TradeSafe**: the GraphQL API calls in `supabase-functions/_shared/tradesafe.ts`
  (auth, `tokenCreate`, `transactionCreate`, `checkoutLink`,
  `allocationStartDelivery`/`allocationAcceptDelivery`/`allocationDisputeDelivery`,
  `transactionCancel`) are grounded in TradeSafe's public docs at
  docs.tradesafe.co.za as of when this was built. Test the whole flow in
  their sandbox before going live — some field names may have shifted since.
- **Pargo**: unlike TradeSafe, Pargo doesn't publish a self-serve REST API
  spec. `pargo-points/index.ts` and `pargo-shipment/index.ts` are fully
  wired up (auth headers, request/response handling, error handling, how
  they plug into checkout) but the exact endpoint URLs and response field
  names are **best-effort placeholders** — see the "READ THIS BEFORE GOING
  LIVE" comment at the top of each file. Once Pargo sends your onboarding
  docs, you'll need to plug in the real values there.
- **Refunds**: `admin-resolve-dispute` deliberately does **not** call
  TradeSafe automatically when an admin sides with the buyer — it just
  flags the order for you to refund manually (or via TradeSafe's merchant
  portal), the same deliberate choice made in the original design. A real
  `transactionCancel` refund mutation is wired up and ready in
  `_shared/tradesafe.ts` (`tradesafeCancelTransaction`) if you'd rather
  automate this later — test it in sandbox first.

## 1. Run the SQL
In the Supabase SQL Editor, run `tradesafe_pargo_migration.sql`. It's
additive and safe to re-run — it adds columns to `orders`/`profiles`, and
creates `wallet_transactions` + `withdrawal_requests`.

## 2. Get your TradeSafe API credentials
Sign up at tradesafe.co.za, register an application in their developer
portal to get a **Client ID** and **Client Secret** (OAuth2 client
credentials). Ask them to confirm the sandbox hostnames for testing —
production defaults are baked into `_shared/tradesafe.ts`.

```
supabase secrets set TRADESAFE_CLIENT_ID=xxxxx TRADESAFE_CLIENT_SECRET=xxxxx --project-ref spupfdclswjlpwiebwlq
```

Optional overrides (only needed for sandbox testing or if TradeSafe's fee
allocation default doesn't suit you):
```
supabase secrets set TRADESAFE_AUTH_URL=https://... TRADESAFE_API_URL=https://.../graphql --project-ref spupfdclswjlpwiebwlq
supabase secrets set TRADESAFE_FEE_ALLOCATION=BUYER --project-ref spupfdclswjlpwiebwlq   # or SELLER
```

## 3. Get your Pargo credentials
Sign up as a Pargo merchant. They'll email you an API auth token and their
integration docs (endpoint URLs + payload shapes).

```
supabase secrets set PARGO_API_TOKEN=xxxxx --project-ref spupfdclswjlpwiebwlq
supabase secrets set PARGO_POINTS_URL=https://... --project-ref spupfdclswjlpwiebwlq
supabase secrets set PARGO_SHIPMENT_URL=https://... --project-ref spupfdclswjlpwiebwlq
```
Then adjust the response-field mapping near the bottom of `pargo-points/index.ts`
and `pargo-shipment/index.ts` to match what Pargo actually sends back.

## 4. Deploy the edge functions
```
supabase functions deploy tradesafe-checkout --project-ref spupfdclswjlpwiebwlq
supabase functions deploy tradesafe-verify --project-ref spupfdclswjlpwiebwlq
supabase functions deploy tradesafe-webhook --no-verify-jwt --project-ref spupfdclswjlpwiebwlq
supabase functions deploy pargo-points --project-ref spupfdclswjlpwiebwlq
supabase functions deploy pargo-shipment --project-ref spupfdclswjlpwiebwlq
supabase functions deploy pargo-webhook --no-verify-jwt --project-ref spupfdclswjlpwiebwlq
supabase functions deploy confirm-handover-pin --project-ref spupfdclswjlpwiebwlq
supabase functions deploy open-dispute --project-ref spupfdclswjlpwiebwlq
supabase functions deploy admin-resolve-dispute --project-ref spupfdclswjlpwiebwlq
supabase functions deploy release-escrow-cron --no-verify-jwt --project-ref spupfdclswjlpwiebwlq
```
(`_shared/tradesafe.ts` is bundled in automatically via the relative import
— no separate deploy step for it.)

## 5. Schedule the auto-release cron
Supabase Dashboard → Edge Functions → `release-escrow-cron` → Add schedule
→ every 15 minutes (`*/15 * * * *`). This is what auto-releases Pargo
orders 24h after delivery if nobody disputes them, independently of
TradeSafe's own timer.

## 6. Point Pargo's delivery webhook here
In your Pargo merchant portal (or per-shipment via `webhook_url` in
`pargo-shipment/index.ts`), set the delivery-status callback to:
```
https://spupfdclswjlpwiebwlq.supabase.co/functions/v1/pargo-webhook
```

## 7. Ask TradeSafe about webhooks
Their public docs describe redirect Success/Failure/Cancel URLs, not a
documented outbound webhook. Ask your TradeSafe account manager if one
exists for your account; if so, point it at:
```
https://spupfdclswjlpwiebwlq.supabase.co/functions/v1/tradesafe-webhook
```
and add whatever signature/secret check they specify at the top of that
function. Until then, `escrow-return.html` (which calls `tradesafe-verify`
right after the buyer is redirected back) is the source of truth.

## 8. Test it end-to-end (sandbox)
1. As a buyer, open an item → **🔒 Pay Securely Online (Escrow)**.
2. Pick "In-person handover", pay with a TradeSafe sandbox test card.
3. You should land on `escrow-return.html` showing "Payment received".
4. Check `orders` in Supabase: `payment_status='paid'`, `escrow_status='held'`,
   `collection_pin` set.
5. As the seller, go to Orders → enter that PIN → **Confirm & Release**.
6. `escrow_status` should flip to `released`, and `profiles.wallet_balance`
   for the seller should increase by the order total.
7. Repeat with "Pargo pickup point" once your Pargo sandbox is set up —
   confirm `pargo-webhook` sets `delivered_at`/`escrow_release_at`, and that
   `release-escrow-cron` releases it ~24h later (or temporarily shorten the
   24h window in `pargo-webhook/index.ts` while testing).
8. Test a dispute: as the buyer, tap **Report a problem** on a held order,
   then resolve it from Admin → Escrow Disputes (both "Release" and
   "Refund" paths).
9. Test a withdrawal: as the seller, Wallet → **Withdraw to bank**, then
   mark it paid from Admin → Withdrawal Requests.

## 9. Go live
Swap any sandbox URLs/secrets for TradeSafe's and Pargo's production
values. Nothing else changes — same functions, same webhook URLs.
