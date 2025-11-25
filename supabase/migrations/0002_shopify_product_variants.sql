-- ============================================================
-- PRODUCT VARIANTS TABLE
-- ============================================================

create table if not exists public.product_variants (
  id                  bigserial primary key,
  shopify_variant_id  bigint not null,
  shopify_product_id  bigint not null,
  title               text,
  sku                 text,
  price               numeric(12,2) default 0,
  position            integer default 0,
  inventory_quantity  integer,
  requires_shipping   boolean,
  taxable             boolean,
  created_at          timestamptz,
  updated_at          timestamptz,
  inserted_at         timestamptz not null default now()
);

create unique index if not exists product_variants_shopify_variant_id_key
  on public.product_variants (shopify_variant_id);

alter table public.product_variants
  add constraint product_variants_shopify_product_id_fkey
  foreign key (shopify_product_id)
  references public.products (shopify_product_id)
  on delete cascade
  deferrable initially deferred;
