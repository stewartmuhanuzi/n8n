-- Create the updated_at trigger function
create or replace function public.updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;