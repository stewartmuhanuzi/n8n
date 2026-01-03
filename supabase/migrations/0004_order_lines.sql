-- ============================================================
-- ORDER LINES TABLE
-- ============================================================

create table if not exists public.order_lines (
  id                     bigserial primary key,
  shopify_order_id       bigint not null,
  shopify_line_item_id   bigint not null,
  product_id             bigint,
  variant_id             bigint,
  title                  text,
  variant_title          text,
  sku                    text,
  quantity               integer default 0,
  price                  numeric(12,2) default 0,
  fulfillment_status     text,
  fulfillable_quantity   integer default 0,
  raw_line_item_data     jsonb,
  inserted_at            timestamptz not null default now()
);

-- Unique constraint on Shopify line item ID for upsert operations
create unique index if not exists order_lines_shopify_line_item_id_key
  on public.order_lines (shopify_line_item_id);

-- Foreign key relationship to orders table
alter table public.order_lines
  add constraint order_lines_shopify_order_id_fkey
  foreign key (shopify_order_id)
  references public.orders (shopify_order_id)
  on delete cascade
  deferrable initially deferred;

-- Additional indexes for performance
create index if not exists order_lines_shopify_order_id_idx
  on public.order_lines (shopify_order_id);

create index if not exists order_lines_product_id_idx
  on public.order_lines (product_id);

create index if not exists order_lines_variant_id_idx
  on public.order_lines (variant_id);

create index if not exists order_lines_sku_idx
  on public.order_lines (sku);

-- GIN index for JSONB column
create index if not exists order_lines_raw_line_item_data_gin_idx
  on public.order_lines using gin (raw_line_item_data);