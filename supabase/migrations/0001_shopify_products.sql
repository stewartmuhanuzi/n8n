-- ============================================================
-- PRODUCTS TABLE
-- ============================================================

create table if not exists public.products (
  id                 bigserial primary key,
  shopify_product_id bigint not null,
  title              text,
  handle             text,
  body_html          text,
  vendor             text,
  product_type       text,
  status             text,
  tags               text,
  created_at         timestamptz,
  updated_at         timestamptz,
  published_at       timestamptz,
  inserted_at        timestamptz not null default now()
);

create unique index if not exists products_shopify_product_id_key
  on public.products (shopify_product_id);
