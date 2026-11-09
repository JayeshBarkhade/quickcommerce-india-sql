-- Phase 2a: DATA-QUALITY REPORT on the raw staging data (run BEFORE cleaning).
-- Each row = one issue, how many rows it touches, and how the transform handles it.
SELECT issue, affected_rows, handling FROM (
  SELECT 1 AS n, 'Distinct spellings of payment_method (should be 5 methods)' AS issue,
         (SELECT count(DISTINCT payment_method) FROM staging.orders) AS affected_rows,
         'Normalised to UPI / CARD / COD / WALLET / NETBANKING' AS handling
  UNION ALL SELECT 2, 'Distinct spellings of order status (should be 2)',
         (SELECT count(DISTINCT status) FROM staging.orders), 'lower(trim()), "canceled" -> "cancelled"'
  UNION ALL SELECT 3, 'Orders delivered BEFORE they were placed',
         (SELECT count(*) FROM staging.orders WHERE lower(status) = 'delivered'
            AND NULLIF(delivered_ts, '')::timestamp < order_ts::timestamp),
         'delivered_ts set NULL, row kept, dq_flag = delivered_before_order'
  UNION ALL SELECT 4, 'Status delivered but no delivery time',
         (SELECT count(*) FROM staging.orders WHERE lower(status) = 'delivered' AND NULLIF(delivered_ts, '') IS NULL),
         'Row kept, dq_flag = delivered_missing_date; excluded from delivery-time analysis'
  UNION ALL SELECT 5, 'Cancelled orders that still carry a delivery time',
         (SELECT count(*) FROM staging.orders WHERE lower(status) IN ('cancelled', 'canceled') AND NULLIF(delivered_ts, '') IS NOT NULL),
         'delivered_ts set NULL, dq_flag = cancelled_with_delivery_ts'
  UNION ALL SELECT 6, 'Double-posted order lines (same order_id + line_no twice)',
         (SELECT count(*) - count(DISTINCT (order_id, line_no)) FROM staging.order_items),
         'ROW_NUMBER() keeps one copy'
  UNION ALL SELECT 7, 'Order lines with quantity 0',
         (SELECT count(*) FROM staging.order_items WHERE quantity::int <= 0), 'Dropped'
  UNION ALL SELECT 8, 'Ratings outside 1-5',
         (SELECT count(*) FROM staging.order_feedback WHERE rating::int NOT BETWEEN 1 AND 5), 'Dropped'
  UNION ALL SELECT 9, 'Orders with more than one rating row',
         (SELECT count(*) FROM (SELECT order_id FROM staging.order_feedback WHERE rating::int BETWEEN 1 AND 5
                                GROUP BY 1 HAVING count(*) > 1) x), 'Latest valid rating kept'
  UNION ALL SELECT 10, 'City spellings that need the alias table (customers + stores)',
         (SELECT count(*) FROM staging.customers WHERE lower(trim(city)) NOT IN
            (SELECT lower(city_name) FROM staging.cities)) +
         (SELECT count(*) FROM staging.stores WHERE lower(trim(city)) NOT IN
            (SELECT lower(city_name) FROM staging.cities)),
         'Mapped through qc.city_alias (Bangalore -> Bengaluru, Gurgaon -> Delhi NCR ...)'
  UNION ALL SELECT 11, 'Unmapped city spellings (must be 0 or the load fails loudly)',
         (SELECT count(*) FROM staging.customers c WHERE NOT EXISTS (SELECT 1 FROM qc.city_alias a WHERE a.alias = lower(trim(c.city)))),
         'NOT NULL constraint on city_id surfaces any gap'
  UNION ALL SELECT 12, 'Distinct spellings of acquisition_channel (should be 5)',
         (SELECT count(DISTINCT acquisition_channel) FROM staging.customers), 'lower / trim / spaces to underscores'
) q ORDER BY n;
