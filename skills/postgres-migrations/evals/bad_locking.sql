-- Dangerous migration example: locks writes, runs CONCURRENTLY inside TX, volatile default, direct SET NOT NULL, no lock_timeout
BEGIN;

CREATE INDEX idx_orders_user_id ON orders (user_id);

CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);

ALTER TABLE orders ADD COLUMN created_at timestamptz DEFAULT now();

ALTER TABLE orders ALTER COLUMN customer_phone SET NOT NULL;

COMMIT;
