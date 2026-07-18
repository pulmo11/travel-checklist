alter table public.travel_companion_data
  add column if not exists checklists jsonb not null default '{}'::jsonb;
