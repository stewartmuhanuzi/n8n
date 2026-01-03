-- Shopify products raw table
create table if not exists public.shopify_products_raw (
  id              bigserial primary key,
  external_id     text not null,
  source_system   text not null default 'shopify',
  event_type      text not null,
  shop_identifier text not null,
  merchant_id     text,

  -- Raw data
  payload         jsonb not null,

  -- Processing status
  processed       boolean not null default false,
  processed_at    timestamptz,

  -- Error handling
  error_message   text,
  retry_count     integer not null default 0,
  max_retries     integer not null default 3,

  received_at     timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Indexes
create index if not exists shopify_products_raw_external_id_shop_idx
  on public.shopify_products_raw (external_id, shop_identifier);
create index if not exists shopify_products_raw_processed_idx
  on public.shopify_products_raw (processed);
create index if not exists shopify_products_raw_unprocessed_idx
  on public.shopify_products_raw (processed, received_at)
  where processed = false;
create index if not exists shopify_products_raw_event_type_idx
  on public.shopify_products_raw (event_type);
create index if not exists shopify_products_raw_shop_identifier_idx
  on public.shopify_products_raw (shop_identifier);
create index if not exists shopify_products_raw_merchant_id_idx
  on public.shopify_products_raw (merchant_id);
create index if not exists shopify_products_raw_received_at_idx
  on public.shopify_products_raw (received_at desc);

-- GIN index for JSONB
create index if not exists shopify_products_raw_payload_gin_idx
  on public.shopify_products_raw using gin (payload);

-- Composite indexes
create index if not exists shopify_products_raw_unprocessed_by_shop_idx
  on public.shopify_products_raw (shop_identifier, processed, received_at)
  where processed = false;
create unique index if not exists shopify_products_raw_unique_product_event_idx
  on public.shopify_products_raw (external_id, event_type, shop_identifier, received_at);

-- Row Level Security
alter table public.shopify_products_raw enable row level security;

-- RLS policies
create policy "Allow service insertion of raw product data"
  on public.shopify_products_raw for insert with check (true);
create policy "Allow service read access to raw product data"
  on public.shopify_products_raw for select using (true);
create policy "Allow service update of raw product data"
  on public.shopify_products_raw for update using (true);

-- Updated timestamp trigger
create trigger update_shopify_products_raw_updated_at
  before update on public.shopify_products_raw
  for each row
  execute function public.updated_at_column();