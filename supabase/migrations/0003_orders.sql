-- ============================================================
-- ORDERS TABLE
-- ============================================================

create table if not exists public.orders (
  id                   bigserial primary key,
  shopify_order_id     bigint not null,
  order_number         text,
  order_name           text,
  customer_email       text,
  customer_first_name  text,
  customer_last_name   text,
  total_price          numeric(12,2) default 0,
  subtotal_price       numeric(12,2) default 0,
  total_tax            numeric(12,2) default 0,
  currency             text default 'USD',
  financial_status     text,
  fulfillment_status   text,
  created_at           timestamptz,
  updated_at           timestamptz,
  processed_at         timestamptz,
  fulfilled_at         timestamptz,
  cancelled_at         timestamptz,
  shipping_address     jsonb,
  tags                 text[],
  note                 text,
  raw_shopify_data     jsonb,
  inserted_at          timestamptz not null default now()
);

-- Unique constraint on Shopify order ID for upsert operations
create unique index if not exists orders_shopify_order_id_key
  on public.orders (shopify_order_id);

-- Additional indexes for performance
create index if not exists orders_order_number_idx
  on public.orders (order_number);

create index if not exists orders_customer_email_idx
  on public.orders (customer_email);

create index if not exists orders_created_at_idx
  on public.orders (created_at);

create index if not exists orders_financial_status_idx
  on public.orders (financial_status);

create index if not exists orders_fulfillment_status_idx
  on public.orders (fulfillment_status);

-- GIN index for array column (tags)
create index if not exists orders_tags_gin_idx
  on public.orders using gin (tags);

-- GIN index for JSONB columns
create index if not exists orders_shipping_address_gin_idx
  on public.orders using gin (shipping_address);

create index if not exists orders_raw_shopify_data_gin_idx
  on public.orders using gin (raw_shopify_data);