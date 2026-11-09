-- Q10. Which dark stores had days with ZERO orders after they opened (outages, closures, or too little demand)?
-- Skills: generate_series, CROSS JOIN to build a full store x day calendar, LEFT JOIN, FILTER.
-- A plain GROUP BY only returns days that HAVE orders; the calendar grid is what exposes the gaps.
WITH days AS (
  SELECT generate_series(min(order_ts)::date, max(order_ts)::date, interval '1 day')::date AS d FROM qc.orders),
daily AS (
  SELECT store_id, order_ts::date AS d, count(*) AS n FROM qc.orders GROUP BY 1, 2)
SELECT st.store_id, ci.city_name, st.locality, count(*) FILTER (WHERE dl.n IS NULL) AS zero_order_days,
       count(*) AS days_open, round(100.0 * count(*) FILTER (WHERE dl.n IS NULL) / count(*), 1) AS pct_zero_days
FROM qc.dark_stores st
JOIN qc.cities ci USING (city_id)
CROSS JOIN days dy
LEFT JOIN daily dl ON dl.store_id = st.store_id AND dl.d = dy.d
WHERE dy.d >= st.opened_date
GROUP BY st.store_id, ci.city_name, st.locality
HAVING count(*) FILTER (WHERE dl.n IS NULL) > 0
ORDER BY zero_order_days DESC, st.store_id LIMIT 12;
