# Scaling notes (toward ~100k users)

Fixes applied so far, in the order they were done:

1. **DB indexes** — `performance_indexes_migration.sql`
2. **Server-side pagination** on the homepage feed (300 rows/page, DB-side)
3. **404 page, robots.txt, sitemap.xml**
4. **New unique VAPID key pair** for push
5. **Server-side rate limiting** — `rate_limiting_migration.sql`
6. Various UI/copy fixes (see prior conversation)
7. **Server-side FILTERING** — category/search/price filters now run as
   real Supabase queries (`buildListingsQuery` in `index.html`), not JS
   filtering over whatever page happened to be in memory. Price filtering
   uses a new generated `effective_price` column (discount already applied)
   so it stays correct without pulling every row into the browser to compute it.
8. **Composite indexes for rate limiting** — `(seller_id, created_at)` /
   `(sender_id, created_at)` / `(reporter_id, created_at)`, matching the
   exact WHERE clauses the rate-limit checks use.
9. **Realtime instead of polling** for messages — `messages.html` now
   subscribes to Postgres changes instead of re-fetching every 10s.
   Requires `enable_realtime_migration.sql` to be run (adds `messages` to
   Supabase's realtime publication) or the subscription receives nothing.
   A slow 60s poll remains only as a fallback if the socket drops.
10. **Image cache headers** — Storage uploads now set a 1-year
    `cacheControl`, safe because filenames are timestamp-unique (upload
    content under a given name never changes).

## What's still platform-dependent, not code

- **CDN for the static pages themselves** (`index.html`, `style.css`, etc.)
  — this is a hosting decision, not something a code change can add. If
  you deploy to Vercel, Netlify, or Cloudflare Pages, static assets are
  automatically served through their CDN with no config needed. If you're
  hosting elsewhere (a plain VPS, etc.), you'd want to put Cloudflare (or
  similar) in front of it yourself.
- **Supabase plan tier** — connection limits, compute size, and
  bandwidth/storage caps on your actual Supabase project set the real
  ceiling underneath all of the above. At meaningful scale (tens of
  thousands of active users) this becomes a Supabase billing/tier decision
  in their dashboard, not a code change.
- **Image compression/sizing at upload time** already happens
  client-side (`compressImage()` in `seller.html`) — worth periodically
  checking that's still producing reasonably small files as the catalog grows.
