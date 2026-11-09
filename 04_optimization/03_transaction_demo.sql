-- Phase 4c: TRANSACTIONS (atomicity). Runs on TEMP copies, so the real tables are never modified.
-- Scenario: cancelling an order must (1) change the status AND clear the delivery time AND (2) write an audit-log row,
-- all or nothing.
CREATE TEMP TABLE orders_demo (LIKE qc.orders INCLUDING ALL);       -- INCLUDING ALL keeps the CHECK constraints
INSERT INTO orders_demo SELECT * FROM qc.orders WHERE status = 'delivered' AND delivered_ts IS NOT NULL ORDER BY order_id LIMIT 3;
CREATE TEMP TABLE order_status_log (log_id bigserial PRIMARY KEY, order_id integer NOT NULL, old_status text,
                                    new_status text, changed_at timestamptz DEFAULT now());
SELECT order_id AS oid1 FROM orders_demo ORDER BY order_id LIMIT 1 \gset
SELECT order_id AS oid2 FROM orders_demo ORDER BY order_id OFFSET 1 LIMIT 1 \gset
-- psql :variables are not expanded inside $$ bodies, so hand the id to the DO block via a session setting
SELECT set_config('demo.oid2', :'oid2', false) AS passed_to_do_block \gset

\echo '== A. Successful transaction: both statements commit together'
BEGIN;
  UPDATE orders_demo SET status = 'cancelled', delivered_ts = NULL WHERE order_id = :oid1;
  INSERT INTO order_status_log (order_id, old_status, new_status) VALUES (:oid1, 'delivered', 'cancelled');
COMMIT;
SELECT order_id, status, delivered_ts IS NOT NULL AS has_delivery_time FROM orders_demo ORDER BY order_id;
SELECT order_id, old_status, new_status FROM order_status_log;

\echo '== B. Failing statement inside a transaction block: the whole block is undone (CHECK violation)'
DO $$
BEGIN
  BEGIN                                           -- inner block = automatic SAVEPOINT
    UPDATE orders_demo SET status = 'teleported' WHERE order_id = current_setting('demo.oid2')::int;   -- violates CHECK
    INSERT INTO order_status_log (order_id, old_status, new_status) VALUES (current_setting('demo.oid2')::int, 'delivered', 'teleported');
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'rolled back both statements: %', SQLERRM;
  END;
END $$;
SELECT order_id, status FROM orders_demo ORDER BY order_id;
SELECT count(*) AS log_rows_after_failed_attempt FROM order_status_log;     -- still 1: the log insert was undone too

\echo '== C. Explicit ROLLBACK: DELETE everything, look, then undo'
BEGIN;
  DELETE FROM orders_demo;
  SELECT count(*) AS rows_inside_transaction FROM orders_demo;
ROLLBACK;
SELECT count(*) AS rows_after_rollback FROM orders_demo;
