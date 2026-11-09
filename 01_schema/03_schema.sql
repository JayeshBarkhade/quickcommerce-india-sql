-- Phase 1c: CLEAN, typed, normalized schema with constraints. Money is in Indian rupees (Rs).
-- Design notes
--  * Customers, stores and cities are separate tables; messy city spellings (Bangalore / Bengaluru, Gurgaon /
--    Gurugram, Bombay / Mumbai) are resolved through the city_alias lookup table, not scattered CASE statements.
--  * Constraints encode business rules (delivery cannot precede the order, a cancelled order has no delivery time,
--    rating 1-5, non-negative money). The cleaning step exists so these can be enforced.
--  * Secondary indexes are deliberately NOT created here. They are added in 04_optimization with measured
--    before/after timings, so each index is justified by evidence.
DROP SCHEMA IF EXISTS qc CASCADE;
CREATE SCHEMA qc;

CREATE TABLE qc.cities (
    city_id   smallint PRIMARY KEY,
    city_name text NOT NULL UNIQUE,
    tier      smallint NOT NULL CHECK (tier IN (1, 2, 3))
);
CREATE TABLE qc.city_alias (
    alias   text PRIMARY KEY,                       -- lower-cased, trimmed spelling seen in source data
    city_id smallint NOT NULL REFERENCES qc.cities (city_id)
);
-- Reference data: cities come from the (already loaded) staging copy, aliases are curated by hand.
INSERT INTO qc.cities SELECT city_id::smallint, city_name, tier::smallint FROM staging.cities;
INSERT INTO qc.city_alias VALUES
 ('delhi',1),('new delhi',1),('gurgaon',1),('gurugram',1),('noida',1),('delhi ncr',1),
 ('mumbai',2),('bombay',2),('navi mumbai',2),('thane',2),('bengaluru',3),('bangalore',3),
 ('hyderabad',4),('hyderbad',4),('pune',5),('chennai',6),('kolkata',7),('calcutta',7),
 ('ahmedabad',8),('ahmadabad',8),('jaipur',9),('lucknow',10);

CREATE TABLE qc.dark_stores (
    store_id    integer PRIMARY KEY,
    city_id     smallint NOT NULL REFERENCES qc.cities (city_id),
    locality    text NOT NULL,
    opened_date date NOT NULL
);
CREATE TABLE qc.customers (
    customer_id         integer PRIMARY KEY,
    signup_date         date NOT NULL,
    city_id             smallint NOT NULL REFERENCES qc.cities (city_id),
    acquisition_channel text NOT NULL CHECK (acquisition_channel IN
        ('organic', 'paid_social', 'referral', 'influencer', 'app_store'))
);
CREATE TABLE qc.product_categories (
    category_id   smallint PRIMARY KEY,
    category_name text NOT NULL UNIQUE
);
CREATE TABLE qc.products (
    product_id   integer PRIMARY KEY,
    category_id  smallint NOT NULL REFERENCES qc.product_categories (category_id),
    product_name text NOT NULL,
    mrp          numeric(8,2) NOT NULL CHECK (mrp > 0)
);
CREATE TABLE qc.orders (
    order_id         integer PRIMARY KEY,
    customer_id      integer NOT NULL REFERENCES qc.customers (customer_id),
    store_id         integer NOT NULL REFERENCES qc.dark_stores (store_id),
    order_ts         timestamp NOT NULL,
    promised_minutes smallint NOT NULL CHECK (promised_minutes > 0),
    delivered_ts     timestamp,
    status           text NOT NULL CHECK (status IN ('delivered', 'cancelled')),
    payment_method   text NOT NULL CHECK (payment_method IN ('UPI', 'CARD', 'COD', 'WALLET', 'NETBANKING')),
    delivery_fee     numeric(6,2) NOT NULL CHECK (delivery_fee >= 0),
    handling_fee     numeric(6,2) NOT NULL CHECK (handling_fee >= 0),
    discount_amount  numeric(8,2) NOT NULL CHECK (discount_amount >= 0),
    amount_paid      numeric(9,2) NOT NULL CHECK (amount_paid >= 0),
    dq_flag          text,   -- set by the cleaning step when a source value was repaired
    CONSTRAINT delivered_after_order CHECK (delivered_ts IS NULL OR delivered_ts >= order_ts),
    CONSTRAINT cancelled_has_no_delivery CHECK (status <> 'cancelled' OR delivered_ts IS NULL)
);
CREATE TABLE qc.order_items (
    order_id   integer NOT NULL REFERENCES qc.orders (order_id),
    line_no    smallint NOT NULL,
    product_id integer NOT NULL REFERENCES qc.products (product_id),
    quantity   smallint NOT NULL CHECK (quantity > 0),
    unit_price numeric(8,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, line_no)
);
CREATE TABLE qc.order_feedback (
    order_id   integer PRIMARY KEY REFERENCES qc.orders (order_id),     -- one rating per order after dedupe
    rating     smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    tag        text,
    created_ts timestamp
);
CREATE TABLE qc.weather_daily (
    city_id     smallint NOT NULL REFERENCES qc.cities (city_id),
    day         date NOT NULL,
    rainfall_mm numeric(6,1) NOT NULL CHECK (rainfall_mm >= 0),
    PRIMARY KEY (city_id, day)
);
