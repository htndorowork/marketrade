# Paystack go-live checklist

Your Supabase project ref is **`spupfdclswjlpwiebwlq`** — use that in every
command below.

Paystack coexists with the existing PayFast integration — sellers can pick
either on the Change Plan screen (a toggle above the plan cards), and both
write to the same `subscription_payments` table so admin views work either
way.

## 1. Run the SQL
In the Supabase SQL Editor, run `paystack_support_migration.sql` (adds a
`gateway` column to `subscription_payments` — everything else already
exists from the PayFast setup).

## 2. Get your Paystack API keys
Once your Paystack business account is approved: Dashboard → Settings →
API Keys & Webhooks. You'll see a **test** secret key (`sk_test_...`) and,
once live, a **live** secret key (`sk_live_...`). Unlike PayFast, there's
no separate sandbox flag — whichever key you set determines the mode.

## 3. Set the secret
```
supabase secrets set PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxx --project-ref spupfdclswjlpwiebwlq
```
Start with the test key. Swap to `sk_live_...` when you're ready to go live
— that's the only change needed to switch modes.

## 4. Deploy the edge functions
```
supabase functions deploy paystack-checkout --project-ref spupfdclswjlpwiebwlq
supabase functions deploy paystack-webhook --no-verify-jwt --project-ref spupfdclswjlpwiebwlq
```

## 5. Set the webhook URL in Paystack's dashboard
Dashboard → Settings → API Keys & Webhooks → Webhook URL:
```
https://spupfdclswjlpwiebwlq.supabase.co/functions/v1/paystack-webhook
```
**Set this in both the test and live webhook URL fields** — they're
separate settings in Paystack's dashboard, and both need it.

## 6. Test it
1. With the test secret key set, go to Seller Dashboard → Change Plan →
   tap the "Paystack" toggle → pick a plan.
2. You'll be redirected straight to Paystack's hosted checkout (no form
   fields to fill in on our side — Paystack handles the whole page).
3. Use one of Paystack's published test cards (check their docs for the
   current test card numbers/OTP).
4. You should land back on `payment-return.html`, and shortly after your
   seller plan should show as active.
5. Check `subscription_payments` in Supabase — the row (id starting
   `ps_`) should flip from `pending` to `completed`, with `gateway` set
   to `paystack`.
6. If it doesn't update, check the `paystack-webhook` function logs
   (Supabase Dashboard → Edge Functions → paystack-webhook → Logs).

## 7. Go live
```
supabase secrets set PAYSTACK_SECRET_KEY=sk_live_xxxxxxxxxxxxx --project-ref spupfdclswjlpwiebwlq
```
Nothing else needs to change — the webhook URL and function code stay the
same in test and live mode.

## Which gateway is "default"?
The toggle on Change Plan remembers the seller's last choice
(`localStorage`), defaulting to PayFast. If you want Paystack to be the
default for everyone, change the fallback in `seller.html`:
```js
let selectedGateway = localStorage.getItem('mt_pay_gateway') || 'payfast';
```
→ change `'payfast'` to `'paystack'`.
