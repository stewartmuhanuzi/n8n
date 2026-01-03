ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS image_url text,
ADD COLUMN IF NOT EXISTS inventory_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_synced_at timestamptz;