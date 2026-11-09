-- Shared building block. Revenue ("GMV") = amount actually paid by the customer in Rs (items + delivery/handling fees
-- - discount) on DELIVERED orders. delivery_minutes and sla_met are NULL when the source delivery time was unusable
-- (those rows carry a dq_flag), so averages and percentiles automatically ignore them.
CREATE OR REPLACE VIEW qc.v_delivered_orders AS
SELECT o.order_id, o.customer_id, o.store_id, s.city_id, o.order_ts, o.delivered_ts, o.promised_minutes,
       EXTRACT(epoch FROM o.delivered_ts - o.order_ts) / 60.0 AS delivery_minutes,
       (EXTRACT(epoch FROM o.delivered_ts - o.order_ts) / 60.0 <= o.promised_minutes) AS sla_met,
       o.amount_paid, o.discount_amount, o.payment_method, o.dq_flag
FROM qc.orders o
JOIN qc.dark_stores s USING (store_id)
WHERE o.status = 'delivered';
