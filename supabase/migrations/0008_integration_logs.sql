-- Integration logs table
create type integration_status as enum (
  'pending', 'running', 'success', 'partial',
  'failed', 'retrying', 'cancelled'
);

create type flow_type as enum (
  'fetch_orders', 'fetch_products', 'process_orders', 'process_products',
  'webhook_process', 'sync_full', 'sync_incremental', 'cleanup',
  'reconciliation', 'bulk_import', 'export', 'validation',
  'transformation', 'custom'
);

create table if not exists public.integration_logs (
  id              bigserial primary key,

  -- Flow identification
  flow_name       text not null,
  flow_type       flow_type not null,
  source_system   text not null default 'shopify',

  -- Multi-tenant support
  shop_identifier text not null,
  merchant_id     text,

  -- Flow execution
  status          integration_status not null default 'pending',
  started_at      timestamptz not null default now(),
  completed_at    timestamptz,
  duration_ms     bigint,

  -- Data metrics
  records_total   integer default 0,
  records_success integer default 0,
  records_failed  integer default 0,
  records_skipped integer default 0,
  records_updated integer default 0,

  -- Error handling
  error_message   text,
  error_details   jsonb,
  stack_trace     text,

  -- Retry information
  retry_count     integer not null default 0,
  max_retries     integer not null default 3,
  next_retry_at   timestamptz,

  -- Context and metadata
  context         jsonb,
  metadata        jsonb,
  version         text,
  triggered_by    text,
  correlation_id  text,

  -- External references
  external_flow_id text,
  parent_log_id   bigint,
  child_log_count integer default 0,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Indexes
create index if not exists integration_logs_flow_name_idx on public.integration_logs (flow_name);
create index if not exists integration_logs_flow_type_idx on public.integration_logs (flow_type);
create index if not exists integration_logs_status_idx on public.integration_logs (status);
create index if not exists integration_logs_shop_identifier_idx on public.integration_logs (shop_identifier);
create index if not exists integration_logs_merchant_id_idx on public.integration_logs (merchant_id);
create index if not exists integration_logs_started_at_idx on public.integration_logs (started_at desc);
create index if not exists integration_logs_completed_at_idx on public.integration_logs (completed_at desc);
create index if not exists integration_logs_correlation_id_idx on public.integration_logs (correlation_id);

-- Composite indexes
create index if not exists integration_logs_shop_status_started_idx
  on public.integration_logs (shop_identifier, status, started_at desc);
create index if not exists integration_logs_flow_type_status_idx
  on public.integration_logs (flow_type, status, started_at desc);
create index if not exists integration_logs_retry_needed_idx
  on public.integration_logs (status, next_retry_at)
  where status in ('failed', 'retrying') and next_retry_at is not null;
create index if not exists integration_logs_running_idx
  on public.integration_logs (status, started_at)
  where status = 'running';

-- GIN indexes for JSONB
create index if not exists integration_logs_context_gin_idx on public.integration_logs using gin (context);
create index if not exists integration_logs_metadata_gin_idx on public.integration_logs using gin (metadata);
create index if not exists integration_logs_error_details_gin_idx on public.integration_logs using gin (error_details);

-- Foreign key for parent-child flows
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'integration_logs_parent_log_id_fkey'
  ) then
    alter table public.integration_logs
      add constraint integration_logs_parent_log_id_fkey
      foreign key (parent_log_id) references public.integration_logs(id)
      on delete set null;
  end if;
end $$;

-- Row Level Security
alter table public.integration_logs enable row level security;

-- RLS policies
create policy "Allow service insertion of integration logs"
  on public.integration_logs for insert with check (true);
create policy "Allow service read access to integration logs"
  on public.integration_logs for select using (true);
create policy "Allow service update of integration logs"
  on public.integration_logs for update using (true);

-- Function for updated_at trigger
create or replace function public.updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Updated timestamp trigger
create trigger update_integration_logs_updated_at
  before update on public.integration_logs
  for each row
  execute function public.updated_at_column();