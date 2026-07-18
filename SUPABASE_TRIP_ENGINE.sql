-- Festival Passport Trip Engine / Phase A
-- Existing groups and itineraries are preserved and assigned to Fuji Rock.

alter table public.travel_groups
  add column if not exists trip_id text;

alter table public.travel_itineraries
  add column if not exists trip_id text;

update public.travel_groups
set trip_id = 'fuji'
where trip_id is null;

update public.travel_itineraries as itinerary
set trip_id = coalesce(trip_group.trip_id, 'fuji')
from public.travel_groups as trip_group
where itinerary.group_id = trip_group.id
  and itinerary.trip_id is null;

update public.travel_itineraries
set trip_id = 'fuji'
where trip_id is null;

create index if not exists travel_groups_trip_id_idx
  on public.travel_groups(trip_id);

create index if not exists travel_itineraries_trip_id_depart_idx
  on public.travel_itineraries(trip_id, depart_at);

create or replace function public.create_trip_group(p_name text, p_trip_id text)
returns table(group_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  created_id uuid;
  created_code text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if nullif(trim(p_name), '') is null or nullif(trim(p_trip_id), '') is null then
    raise exception 'invalid_trip_group';
  end if;

  created_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.travel_groups(name, owner_id, invite_code, trip_id)
  values (trim(p_name), auth.uid(), created_code, trim(p_trip_id))
  returning id into created_id;

  insert into public.travel_group_members(group_id, user_id)
  values (created_id, auth.uid())
  on conflict do nothing;

  return query select created_id, created_code;
end;
$$;

grant execute on function public.create_trip_group(text, text) to authenticated;
