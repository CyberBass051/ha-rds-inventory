CREATE TABLE IF NOT EXISTS inventory (
    sku          VARCHAR(50) PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    stock        INT NOT NULL CHECK (stock >= 0),
    version      INT NOT NULL DEFAULT 0,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
    order_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku        VARCHAR(50) REFERENCES inventory(sku),
    quantity   INT NOT NULL,
    status     VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);