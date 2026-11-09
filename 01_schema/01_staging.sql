-- Phase 1a: STAGING schema. Everything is text, exactly as it arrives in the CSVs.
-- Rule: never type-cast on the way in. Load first, clean in SQL afterwards, so bad rows can be counted and
-- explained instead of silently failing the load.
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;
CREATE TABLE staging.cities (city_id text, city_name text, tier text);
CREATE TABLE staging.stores (store_id text, city text, locality text, opened_date text);
CREATE TABLE staging.customers (customer_id text, signup_date text, city text, acquisition_channel text);
CREATE TABLE staging.products (product_id text, category_name text, product_name text, mrp text);
CREATE TABLE staging.orders (order_id text, customer_id text, store_id text, order_ts text, promised_minutes text,
                             delivered_ts text, status text, payment_method text, delivery_fee text, handling_fee text,
                             discount_amount text, amount_paid text);
CREATE TABLE staging.order_items (order_id text, line_no text, product_id text, quantity text, unit_price text);
CREATE TABLE staging.order_feedback (order_id text, rating text, tag text, created_ts text);
CREATE TABLE staging.weather_daily (city_id text, day text, rainfall_mm text);
