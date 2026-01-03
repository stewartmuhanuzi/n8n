# API Reference & Database Schema

## Overview

This document provides a comprehensive reference for the n8n Shopify Integration Library database schema, including table structures, relationships, indexes, and usage patterns.

## Database Architecture

### Raw Tables vs Normalized Tables

The library implements a **dual-layer data architecture**:

1. **Raw Tables** - Complete, unmodified Shopify API responses
2. **Normalized Tables** - Clean, optimized data for business applications

```
Shopify API
    ↓
Raw Tables (Audit Trail)
    ↓
Transformation & Validation
    ↓
Normalized Tables (Business Ready)
    ↓
Applications & Analytics
```

## Table Schema Reference

### Raw Data Tables

#### `shopify_orders_raw`

Stores complete Shopify order responses for audit trails and re-processing.

```sql
CREATE TABLE shopify_orders_raw (
  id BIGSERIAL PRIMARY KEY,
  external_id TEXT NOT NULL,
  source_system TEXT NOT NULL,              -- 'shopify'
  shop_identifier TEXT,                     -- 'shop-name'
  merchant_id TEXT,                         -- 'merchant-001'
  event_type TEXT,                          -- 'orders/create', 'orders/updated'
  payload JSONB NOT NULL,                   -- Complete Shopify API response
  received_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  next_retry_at TIMESTAMPTZ,
  UNIQUE(external_id, source_system)
);

-- Indexes for efficient querying
CREATE INDEX idx_shopify_orders_raw_unprocessed
  ON shopify_orders_raw(processed)
  WHERE processed = FALSE;

CREATE INDEX idx_shopify_orders_raw_shop_unprocessed
  ON shopify_orders_raw(shop_identifier, processed)
  WHERE processed = FALSE;

CREATE INDEX idx_shopify_orders_raw_payload
  ON shopify_orders_raw USING GIN (payload);
```

**Key Fields:**
- `external_id` - Shopify order ID
- `source_system` - Always 'shopify' for Shopify data
- `payload` - Complete JSON response from Shopify API
- `processed` - Flag indicating if transformation has occurred

#### `shopify_products_raw`

Stores complete Shopify product responses including all variants and metadata.

```sql
CREATE TABLE shopify_products_raw (
  id BIGSERIAL PRIMARY KEY,
  external_id TEXT NOT NULL,
  source_system TEXT NOT NULL,              -- 'shopify'
  shop_identifier TEXT,
  merchant_id TEXT,
  event_type TEXT,                          -- 'products/create', 'products/update'
  payload JSONB NOT NULL,                   -- Complete Shopify API response
  received_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  next_retry_at TIMESTAMPTZ,
  UNIQUE(external_id, source_system)
);

-- Indexes for efficient querying
CREATE INDEX idx_shopify_products_raw_unprocessed
  ON shopify_products_raw(processed)
  WHERE processed = FALSE;

CREATE INDEX idx_shopify_products_raw_shop_unprocessed
  ON shopify_products_raw(shop_identifier, processed)
  WHERE processed = FALSE;

CREATE INDEX idx_shopify_products_raw_payload
  ON shopify_products_raw USING GIN (payload);
```

### Normalized Tables

#### `orders`

Clean, normalized order data optimized for queries and business logic.

```sql
CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,
  raw_id BIGINT REFERENCES shopify_orders_raw(id),
  external_id TEXT NOT NULL,
  source_system TEXT NOT NULL,              -- 'shopify'
  shop_identifier TEXT,
  merchant_id TEXT,
  order_number BIGINT NOT NULL,
  order_name TEXT,
  customer_email TEXT,
  customer_first_name TEXT,
  customer_last_name TEXT,
  total_price DECIMAL(12,2),
  subtotal_price DECIMAL(12,2),
  total_tax DECIMAL(12,2),
  total_shipping DECIMAL(12,2),
  currency TEXT DEFAULT 'USD',
  financial_status TEXT,                    -- 'pending', 'paid', 'refunded', 'voided'
  fulfillment_status TEXT,                  -- 'fulfilled', 'partial', 'unfulfilled'
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  shipping_address JSONB,
  billing_address JSONB,
  tags TEXT[],
  note TEXT,
  raw_shopify_data JSONB,
  UNIQUE(external_id, source_system)
);

-- Performance indexes
CREATE INDEX idx_orders_external_source ON orders(external_id, source_system);
CREATE INDEX idx_orders_shop_date ON orders(shop_identifier, created_at);
CREATE INDEX idx_orders_customer ON orders(merchant_id, customer_email);
CREATE INDEX idx_orders_status ON orders(financial_status, fulfillment_status);
CREATE INDEX idx_orders_currency ON orders(currency);
CREATE INDEX idx_orders_synced ON orders(synced_at);
CREATE INDEX idx_orders_composite ON orders(merchant_id, created_at, financial_status);
CREATE INDEX idx_orders_addresses ON orders USING GIN (shipping_address, billing_address);
```

#### `order_lines`

Individual line items within orders, linked to products and variants.

```sql
CREATE TABLE order_lines (
  id BIGSERIAL PRIMARY KEY,
  raw_id BIGINT REFERENCES shopify_orders_raw(id),
  external_id TEXT NOT NULL,
  source_system TEXT NOT NULL,              -- 'shopify'
  shop_identifier TEXT,
  merchant_id TEXT,
  order_id BIGINT NOT NULL,
  order_external_id TEXT NOT NULL,
  product_id BIGINT,
  product_external_id TEXT,
  variant_id BIGINT,
  variant_external_id TEXT,
  title TEXT NOT NULL,
  variant_title TEXT,
  sku TEXT,
  quantity INTEGER NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  total_discount DECIMAL(12,2) DEFAULT 0,
  fulfillment_status TEXT,                  -- 'fulfilled', 'partial', 'unfulfilled'
  fulfillable_quantity INTEGER DEFAULT 0,
  raw_line_item_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(external_id, source_system)
);

-- Performance indexes
CREATE INDEX idx_order_lines_order_id ON order_lines(order_id, order_external_id);
CREATE INDEX idx_order_lines_product ON order_lines(product_id, product_external_id);
CREATE INDEX idx_order_lines_variant ON order_lines(variant_id, variant_external_id);
CREATE INDEX idx_order_lines_sku ON order_lines(sku);
CREATE INDEX idx_order_lines_shop ON order_lines(shop_identifier, order_external_id);
CREATE INDEX idx_order_lines_composite ON order_lines(merchant_id, order_id, created_at);
CREATE INDEX idx_order_lines_data ON order_lines USING GIN (raw_line_item_data);

-- Foreign key constraints
ALTER TABLE order_lines
  ADD CONSTRAINT fk_order_lines_orders
  FOREIGN KEY (order_external_id, source_system)
  REFERENCES orders(external_id, source_system)
  ON DELETE CASCADE;
```

#### `products`

Normalized product catalog data optimized for search and reporting.

```sql
CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,
  raw_id BIGINT REFERENCES shopify_products_raw(id),
  external_id TEXT NOT NULL,
  source_system TEXT NOT NULL,              -- 'shopify'
  shop_identifier TEXT,
  merchant_id TEXT,
  title TEXT NOT NULL,
  handle TEXT,                              -- URL-friendly product identifier
  body_html TEXT,
  vendor TEXT,
  product_type TEXT,
  status TEXT DEFAULT 'active',             -- 'active', 'archived', 'draft'
  tags TEXT[],
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  published_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  raw_shopify_data JSONB,
  UNIQUE(external_id, source_system)
);

-- Performance indexes
CREATE INDEX idx_products_external_source ON products(external_id, source_system);
CREATE INDEX idx_products_shop_date ON products(shop_identifier, created_at);
CREATE INDEX idx_products_vendor ON products(merchant_id, vendor);
CREATE INDEX idx_products_type ON products(product_type);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_handle ON products(handle);
CREATE INDEX idx_products_tags ON products USING GIN (tags);
CREATE INDEX idx_products_composite ON products(merchant_id, status, updated_at);
CREATE INDEX idx_products_search ON products USING GIN (
  to_tsvector('english', title || ' ' || COALESCE(vendor, '') || ' ' || COALESCE(product_type, ''))
);
```

#### `product_variants`

Product variant data including SKUs, pricing, and inventory.

```sql
CREATE TABLE product_variants (
  id BIGSERIAL PRIMARY KEY,
  raw_id BIGINT REFERENCES shopify_products_raw(id),
  external_id TEXT NOT NULL,
  source_system TEXT NOT NULL,              -- 'shopify'
  shop_identifier TEXT,
  merchant_id TEXT,
  product_external_id TEXT NOT NULL,
  title TEXT,
  sku TEXT,
  price DECIMAL(12,2) NOT NULL,
  compare_at_price DECIMAL(12,2),
  position INTEGER DEFAULT 1,
  inventory_quantity INTEGER,
  inventory_policy TEXT DEFAULT 'deny',     -- 'deny', 'continue'
  inventory_management TEXT,                -- 'shopify', null
  inventory_item_id BIGINT,
  requires_shipping BOOLEAN DEFAULT TRUE,
  taxable BOOLEAN DEFAULT TRUE,
  weight DECIMAL(8,2),
  weight_unit TEXT DEFAULT 'kg',
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  raw_variant_data JSONB,
  UNIQUE(external_id, source_system)
);

-- Performance indexes
CREATE INDEX idx_product_variants_external_source ON product_variants(external_id, source_system);
CREATE INDEX idx_product_variants_product ON product_variants(product_external_id);
CREATE INDEX idx_product_variants_sku ON product_variants(sku);
CREATE INDEX idx_product_variants_shop ON product_variants(shop_identifier, product_external_id);
CREATE INDEX idx_product_variants_price ON product_variants(price);
CREATE INDEX idx_product_variants_inventory ON product_variants(inventory_quantity);
CREATE INDEX idx_product_variants_composite ON product_variants(merchant_id, product_external_id, position);
CREATE INDEX idx_product_variants_data ON product_variants USING GIN (raw_variant_data);

-- Foreign key constraints
ALTER TABLE product_variants
  ADD CONSTRAINT fk_product_variants_products
  FOREIGN KEY (product_external_id, source_system)
  REFERENCES products(external_id, source_system)
  ON DELETE CASCADE;
```

### Logging & Monitoring Tables

#### `integration_logs`

Comprehensive logging for all workflow executions and system events.

```sql
CREATE TABLE integration_logs (
  id BIGSERIAL PRIMARY KEY,
  flow_name TEXT NOT NULL,                  -- 'orders-fetch', 'products-transform'
  source_system TEXT,                       -- 'shopify', 'database'
  flow_type TEXT NOT NULL CHECK (flow_type IN (
    'fetch_orders', 'fetch_products', 'process_orders', 'process_products',
    'webhook_process', 'sync_full', 'sync_incremental', 'monitoring', 'cleanup'
  )),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending', 'running', 'success', 'partial', 'failed', 'retrying', 'cancelled'
  )),
  records_total INTEGER DEFAULT 0,
  records_success INTEGER DEFAULT 0,
  records_failed INTEGER DEFAULT 0,
  records_skipped INTEGER DEFAULT 0,
  records_updated INTEGER DEFAULT 0,
  error_message TEXT,
  error_details JSONB,
  context JSONB DEFAULT '{}',               -- Flow parameters, configuration
  metadata JSONB DEFAULT '{}',              -- Additional information
  correlation_id TEXT,                      -- Links related executions
  parent_log_id BIGINT REFERENCES integration_logs(id),
  child_log_count INTEGER DEFAULT 0,
  duration_ms INTEGER,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  next_retry_at TIMESTAMPTZ,
  shop_identifier TEXT,
  merchant_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_integration_logs_flow_status ON integration_logs(flow_name, status);
CREATE INDEX idx_integration_logs_created_at ON integration_logs(created_at DESC);
CREATE INDEX idx_integration_logs_merchant ON integration_logs(merchant_id);
CREATE INDEX idx_integration_logs_correlation ON integration_logs(correlation_id);
CREATE INDEX idx_integration_logs_retry ON integration_logs(next_retry_at) WHERE status IN ('retrying', 'failed');
CREATE INDEX idx_integration_logs_running ON integration_logs(status) WHERE status = 'running';
CREATE INDEX idx_integration_logs_composite ON integration_logs(merchant_id, flow_name, created_at DESC);
CREATE INDEX idx_integration_logs_details ON integration_logs USING GIN (context, metadata, error_details);
```

#### `sync_log` (Legacy)

Legacy sync tracking for backward compatibility.

```sql
CREATE TABLE sync_log (
  id BIGSERIAL PRIMARY KEY,
  sync_type TEXT NOT NULL,                   -- 'orders', 'products'
  orders_fetched INTEGER DEFAULT 0,
  line_items_fetched INTEGER DEFAULT 0,
  products_fetched INTEGER DEFAULT 0,
  variants_fetched INTEGER DEFAULT 0,
  errors_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'success',             -- 'success', 'partial', 'failed'
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_sync_log_type_created ON sync_log(sync_type, created_at DESC);
CREATE INDEX idx_sync_log_status ON sync_log(status);
```

## Data Relationships

### Entity Relationship Diagram

```
shopify_orders_raw
    ↓ (1:1)
orders
    ↓ (1:N)
order_lines ←→ products ←→ product_variants
    ↑                    ↑              ↑
    │                    │              │
shopify_products_raw ───┘              │
                                   shopify_products_raw
```

### Key Relationships

1. **Raw to Normalized**: Each normalized record links to its source raw record
2. **Orders to Order Lines**: One-to-many relationship via `order_external_id`
3. **Products to Variants**: One-to-many relationship via `product_external_id`
4. **Order Lines to Products**: Many-to-one via `product_external_id`
5. **Integration Logs**: Hierarchical relationship via `parent_log_id`

## Query Patterns & Examples

### Common Business Queries

**Total Revenue by Merchant**
```sql
SELECT
  merchant_id,
  SUM(total_price) as total_revenue,
  COUNT(*) as order_count,
  AVG(total_price) as avg_order_value,
  DATE_TRUNC('month', created_at) as month
FROM orders
WHERE created_at >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
GROUP BY merchant_id, DATE_TRUNC('month', created_at)
ORDER BY month DESC, total_revenue DESC;
```

**Top Selling Products**
```sql
SELECT
  p.title,
  p.vendor,
  p.product_type,
  SUM(ol.quantity) as total_quantity,
  SUM(ol.quantity * ol.price) as total_revenue,
  COUNT(DISTINCT ol.order_id) as order_count
FROM order_lines ol
JOIN products p ON ol.product_external_id = p.external_id
  AND ol.source_system = p.source_system
WHERE ol.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.external_id, p.title, p.vendor, p.product_type
ORDER BY total_revenue DESC
LIMIT 50;
```

**Inventory Levels**
```sql
SELECT
  p.title as product_title,
  pv.sku,
  pv.title as variant_title,
  pv.inventory_quantity,
  pv.inventory_management,
  pv.price,
  CASE
    WHEN pv.inventory_quantity <= 0 THEN 'Out of Stock'
    WHEN pv.inventory_quantity <= 10 THEN 'Low Stock'
    ELSE 'In Stock'
  END as stock_status
FROM product_variants pv
JOIN products p ON pv.product_external_id = p.external_id
  AND pv.source_system = p.source_system
WHERE p.status = 'active'
  AND pv.inventory_management = 'shopify'
ORDER BY pv.inventory_quantity ASC;
```

**Sync Health Monitoring**
```sql
-- Recent sync executions
SELECT
  flow_name,
  status,
  records_total,
  records_success,
  records_failed,
  duration_ms,
  created_at,
  CASE
    WHEN status = 'success' THEN '✅'
    WHEN status = 'failed' THEN '❌'
    WHEN status = 'running' THEN '🔄'
    ELSE '⚠️'
  END as status_icon
FROM integration_logs
WHERE created_at >= CURRENT_DATE - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- Error analysis
SELECT
  flow_name,
  error_message,
  COUNT(*) as error_count,
  MAX(created_at) as last_occurrence
FROM integration_logs
WHERE status = 'failed'
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY flow_name, error_message
ORDER BY error_count DESC, last_occurrence DESC;
```

### Data Quality Checks

**Missing Foreign Keys**
```sql
-- Order lines without valid product references
SELECT COUNT(*) as orphaned_lines
FROM order_lines ol
LEFT JOIN products p ON ol.product_external_id = p.external_id
  AND ol.source_system = p.source_system
WHERE p.external_id IS NULL;

-- Products without variants
SELECT COUNT(*) as products_without_variants
FROM products p
LEFT JOIN product_variants pv ON p.external_id = pv.product_external_id
  AND p.source_system = pv.source_system
WHERE pv.external_id IS NULL;
```

**Data Completeness**
```sql
-- Orders with missing customer information
SELECT
  COUNT(*) as total_orders,
  COUNT(CASE WHEN customer_email IS NULL OR customer_email = '' THEN 1 END) as missing_email,
  COUNT(CASE WHEN total_price IS NULL THEN 1 END) as missing_total,
  COUNT(CASE WHEN created_at IS NULL THEN 1 END) as missing_created_date
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';
```

## Performance Optimization

### Index Strategy

1. **Primary Keys**: All tables have indexed primary keys
2. **Foreign Keys**: All foreign key relationships are indexed
3. **Query Patterns**: Indexes for common query patterns
4. **Composite Indexes**: Multi-column indexes for complex queries
5. **Partial Indexes**: Indexes for specific conditions (unprocessed records)
6. **GIN Indexes**: JSONB text search and array indexing

### Partitioning (for large datasets)

```sql
-- Monthly partitioning for orders (example)
CREATE TABLE orders_partitioned (
  LIKE orders INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE orders_2024_01 PARTITION OF orders_partitioned
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### Materialized Views

```sql
-- Monthly order summary
CREATE MATERIALIZED VIEW monthly_order_summary AS
SELECT
  merchant_id,
  DATE_TRUNC('month', created_at) as month,
  COUNT(*) as order_count,
  SUM(total_price) as total_revenue,
  SUM(total_tax) as total_tax,
  AVG(total_price) as avg_order_value,
  COUNT(DISTINCT customer_email) as unique_customers
FROM orders
GROUP BY merchant_id, DATE_TRUNC('month', created_at);

-- Create unique index for refresh
CREATE UNIQUE INDEX idx_monthly_order_summary_unique
  ON monthly_order_summary(merchant_id, month);

-- Refresh procedure
CREATE OR REPLACE FUNCTION refresh_monthly_summary()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_order_summary;
END;
$$ LANGUAGE plpgsql;
```

## API Access Patterns

### Direct Database Access

```sql
-- Using Supabase REST API
GET /rest/v1/orders?select=*,order_lines(*)&merchant_id=eq.merchant-001&order=created_at.desc

-- Using PostgREST for complex queries
POST /rpc/get_order_details
{
  "merchant_id": "merchant-001",
  "order_external_id": "12345"
}
```

### Custom Functions

```sql
-- Get order details with all related data
CREATE OR REPLACE FUNCTION get_order_details(
  p_merchant_id TEXT,
  p_order_external_id TEXT
)
RETURNS TABLE (
  order_info JSONB,
  line_items JSONB,
  customer_info JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    row_to_json(o.*) as order_info,
    json_agg(row_to_json(ol.*)) as line_items,
    json_build_object(
      'email', o.customer_email,
      'first_name', o.customer_first_name,
      'last_name', o.customer_last_name
    ) as customer_info
  FROM orders o
  LEFT JOIN order_lines ol ON o.external_id = ol.order_external_id
    AND o.source_system = ol.source_system
  WHERE o.merchant_id = p_merchant_id
    AND o.external_id = p_order_external_id
  GROUP BY o.id;
END;
$$ LANGUAGE plpgsql;
```

## Data Migration Patterns

### Backfilling Missing Data

```sql
-- Link orphaned records
UPDATE order_lines ol
SET product_external_id = (
  SELECT MIN(p.external_id)
  FROM products p
  WHERE ol.sku = p.sku
    OR ol.title ILIKE '%' || p.title || '%'
  LIMIT 1
)
WHERE ol.product_external_id IS NULL;
```

### Data Validation

```sql
-- Verify data consistency
WITH data_validation AS (
  SELECT
    'orders' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN external_id IS NULL THEN 1 END) as missing_ids,
    COUNT(CASE WHEN raw_id IS NULL THEN 1 END) as missing_raw_link,
    COUNT(CASE WHEN created_at IS NULL THEN 1 END) as missing_dates
  FROM orders

  UNION ALL

  SELECT
    'order_lines' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN external_id IS NULL THEN 1 END) as missing_ids,
    COUNT(CASE WHEN order_external_id IS NULL THEN 1 END) as missing_order_link,
    COUNT(CASE WHEN quantity IS NULL OR quantity = 0 THEN 1 END) as invalid_quantity
  FROM order_lines
)
SELECT * FROM data_validation;
```

## Security & Access Control

### Row Level Security (RLS)

```sql
-- Enable RLS on sensitive tables
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;

-- Policy for merchant access
CREATE POLICY merchant_access ON orders
  FOR ALL TO authenticated_users
  USING (merchant_id = current_setting('app.current_merchant_id'));

-- Policy for read-only access
CREATE POLICY read_only_access ON integration_logs
  FOR SELECT TO authenticated_users
  USING (merchant_id = current_setting('app.current_merchant_id'));
```

This comprehensive API reference provides all the necessary information for working with the n8n Shopify Integration Library database schema, including table structures, relationships, query patterns, and best practices for performance and security.