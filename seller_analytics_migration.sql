-- ============================================================
-- SELLER ANALYTICS: total sales (daily/weekly/monthly/yearly), orders, and more
-- Run in the MARKETPLACE Supabase SQL Editor. Safe to re-run.
-- ============================================================
--
-- What counts as a "sale": an order with payment_status = 'paid' — i.e. the
-- buyer's payment actually cleared through TradeSafe. This is true the moment
-- payment clears, whether the money is still held in escrow, has been
-- released to the seller's wallet, or is under dispute — it's what the buyer
-- was charged, which is what "sales" means everywhere else (Shopify, Takealot,
-- etc.). Orders that were never paid for (abandoned checkouts) are reported
-- separately as "pending payment" so they don't inflate sales figures.
--
-- Timezone: `orders.created_at` is stored as a naive `timestamp`, written by
-- `now()` on a database whose session timezone is UTC (Supabase's default) —
-- so the stored value IS a UTC wall-clock reading. Every date bucket below
-- converts that UTC reading to Africa/Johannesburg (SAST, UTC+2, no DST)
-- before truncating to a day/week/month/year, so "Today" and "This week"
-- match the seller's own calendar rather than a server clock in another
-- timezone.

CREATE OR REPLACE FUNCTION public.seller_local_time(p_ts timestamp)
RETURNS timestamp
LANGUAGE sql IMMUTABLE
AS $$ SELECT (p_ts AT TIME ZONE 'UTC') AT TIME ZONE 'Africa/Johannesburg' $$;

-- ---------- Summary: today / this week / this month / this year / all-time, + more ----------
CREATE OR REPLACE FUNCTION public.get_seller_analytics_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seller uuid := auth.uid();
  v_now timestamp := public.seller_local_time(now()::timestamp);
  v_today_start timestamp := date_trunc('day', v_now);
  v_week_start timestamp := date_trunc('week', v_now);     -- Monday, per Postgres default
  v_month_start timestamp := date_trunc('month', v_now);
  v_year_start timestamp := date_trunc('year', v_now);
  v_result jsonb;
BEGIN
  IF v_seller IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;

  SELECT jsonb_build_object(
    'today',      jsonb_build_object('revenue', COALESCE(SUM(amount) FILTER (WHERE public.seller_local_time(created_at) >= v_today_start), 0), 'orders', COUNT(*) FILTER (WHERE public.seller_local_time(created_at) >= v_today_start)),
    'this_week',  jsonb_build_object('revenue', COALESCE(SUM(amount) FILTER (WHERE public.seller_local_time(created_at) >= v_week_start), 0), 'orders', COUNT(*) FILTER (WHERE public.seller_local_time(created_at) >= v_week_start)),
    'this_month', jsonb_build_object('revenue', COALESCE(SUM(amount) FILTER (WHERE public.seller_local_time(created_at) >= v_month_start), 0), 'orders', COUNT(*) FILTER (WHERE public.seller_local_time(created_at) >= v_month_start)),
    'this_year',  jsonb_build_object('revenue', COALESCE(SUM(amount) FILTER (WHERE public.seller_local_time(created_at) >= v_year_start), 0), 'orders', COUNT(*) FILTER (WHERE public.seller_local_time(created_at) >= v_year_start)),
    'all_time',   jsonb_build_object('revenue', COALESCE(SUM(amount), 0), 'orders', COUNT(*)),
    'items_sold', COALESCE(SUM(quantity), 0),
    'avg_order_value', CASE WHEN COUNT(*) > 0 THEN ROUND(SUM(amount) / COUNT(*), 2) ELSE 0 END
  )
  INTO v_result
  FROM orders
  WHERE seller_id = v_seller AND payment_status = 'paid';

  -- Non-sale context: money still reserved but not yet a confirmed sale,
  -- money held in escrow vs. released, and anything under dispute.
  v_result := v_result || (
    SELECT jsonb_build_object(
      'pending_payment', jsonb_build_object('count', COUNT(*) FILTER (WHERE payment_status = 'unpaid'), 'amount', COALESCE(SUM(amount) FILTER (WHERE payment_status = 'unpaid'), 0)),
      'in_escrow',        jsonb_build_object('count', COUNT(*) FILTER (WHERE payment_status = 'paid' AND escrow_status = 'held'), 'amount', COALESCE(SUM(amount) FILTER (WHERE payment_status = 'paid' AND escrow_status = 'held'), 0)),
      'completed',        jsonb_build_object('count', COUNT(*) FILTER (WHERE payment_status = 'paid' AND status = 'completed'), 'amount', COALESCE(SUM(amount) FILTER (WHERE payment_status = 'paid' AND status = 'completed'), 0)),
      'disputed',         COUNT(*) FILTER (WHERE payment_status = 'paid' AND escrow_status = 'disputed'),
      'refunded',         COUNT(*) FILTER (WHERE payment_status = 'refunded')
    )
    FROM orders WHERE seller_id = v_seller
  );

  -- Top 5 listings by revenue (all-time, paid orders only)
  v_result := v_result || jsonb_build_object('top_listings', COALESCE((
    SELECT jsonb_agg(row_to_json(t))
    FROM (
      SELECT o.listing_id, COALESCE(l.title, 'Deleted listing') AS title,
             SUM(o.amount) AS revenue, SUM(o.quantity) AS units
      FROM orders o LEFT JOIN listings l ON l.id = o.listing_id
      WHERE o.seller_id = v_seller AND o.payment_status = 'paid'
      GROUP BY o.listing_id, l.title
      ORDER BY SUM(o.amount) DESC
      LIMIT 5
    ) t
  ), '[]'::jsonb));

  RETURN v_result;
END;
$$;

-- ---------- Trend series for the Daily / Weekly / Monthly / Yearly chart ----------
CREATE OR REPLACE FUNCTION public.get_seller_sales_series(p_granularity text)
RETURNS TABLE (period_start date, revenue numeric, orders integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seller uuid := auth.uid();
  v_unit text;
  v_count integer;
  v_now timestamp := public.seller_local_time(now()::timestamp);
BEGIN
  IF v_seller IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  v_unit := CASE p_granularity WHEN 'daily' THEN 'day' WHEN 'weekly' THEN 'week' WHEN 'monthly' THEN 'month' WHEN 'yearly' THEN 'year' ELSE NULL END;
  IF v_unit IS NULL THEN RAISE EXCEPTION 'Invalid granularity'; END IF;
  v_count := CASE p_granularity WHEN 'daily' THEN 30 WHEN 'weekly' THEN 12 WHEN 'monthly' THEN 12 ELSE 6 END;

  RETURN QUERY
  WITH periods AS (
    SELECT date_trunc(v_unit, v_now) - (n || ' ' || v_unit)::interval AS p
    FROM generate_series(0, v_count - 1) AS n
  ),
  sales AS (
    SELECT date_trunc(v_unit, public.seller_local_time(created_at)) AS p,
           SUM(amount) AS revenue, COUNT(*) AS orders
    FROM orders
    WHERE seller_id = v_seller AND payment_status = 'paid'
      AND public.seller_local_time(created_at) >= date_trunc(v_unit, v_now) - ((v_count - 1) || ' ' || v_unit)::interval
    GROUP BY 1
  )
  SELECT periods.p::date, COALESCE(sales.revenue, 0), COALESCE(sales.orders, 0)::integer
  FROM periods LEFT JOIN sales ON sales.p = periods.p
  ORDER BY periods.p;
END;
$$;

REVOKE ALL ON FUNCTION public.get_seller_analytics_summary() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_seller_sales_series(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.seller_local_time(timestamp) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_seller_analytics_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_seller_sales_series(text) TO authenticated;
