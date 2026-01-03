-- ============================================================
-- SYNC LOG TABLE
-- ============================================================

create table if not exists public.sync_log (
  id                 bigserial primary key,
  sync_type          text not null,
  orders_fetched     integer default 0,
  line_items_fetched integer default 0,
  products_fetched   integer default 0,
  variants_fetched   integer default 0,
  errors_count       integer default 0,
  status             text not null check (status in ('success', 'partial', 'failed')),
  error_message      text,
  synced_at          timestamptz not null default now()
);

-- Indexes for performance and querying
create index if not exists sync_log_sync_type_idx
  on public.sync_log (sync_type);

create index if not exists sync_log_status_idx
  on public.sync_log (status);

create index if not exists sync_log_synced_at_idx
  on public.sync_log (synced_at);

create index if not exists sync_log_sync_type_status_idx
  on public.sync_log (sync_type, status);

-- Composite index for common query patterns
create index if not exists sync_log_type_date_idx
  on public.sync_log (sync_type, synced_at desc);