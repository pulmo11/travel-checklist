-- Festival Passport unified travel group platform.
-- Re-runnable migration. Existing groups, members, invite hashes and itineraries are preserved.

create extension if not exists pgcrypto;

alter table public.travel_groups
  add column if not exists trip_id text,
  add column if not exists description text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.travel_group_invites
  add column if not exists invite_code text;

alter table public.travel_itineraries
  add column if not exists trip_id text,
  add column if not exists reference text,
  add column if not exists member_names text[] not null default '{}';

update public.travel_groups set trip_id = 'fuji' where trip_id is null;
update public.travel_itineraries as itinerary
set trip_id = coalesce(trip_group.trip_id, 'fuji')
from public.travel_groups as trip_group
where itinerary.group_id = trip_group.id and itinerary.trip_id is null;

create index if not exists travel_groups_trip_id_idx on public.travel_groups(trip_id);
create index if not exists travel_itineraries_trip_id_depart_idx on public.travel_itineraries(trip_id, depart_at);

alter table public.travel_itineraries drop constraint if exists travel_itineraries_kind_check;
alter table public.travel_itineraries
  add constraint travel_itineraries_kind_check
  check (kind in ('flight', 'train', 'car', 'bus', 'taxi', 'other'));

create or replace function public.is_travel_group_member(p_group_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists(
    select 1 from public.travel_group_members
    where group_id = p_group_id and user_id = auth.uid()
  )
$$;

create or replace function public.is_travel_group_owner(p_group_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists(
    select 1 from public.travel_groups
    where id = p_group_id and owner_id = auth.uid()
  )
$$;

drop policy if exists "members read groups" on public.travel_groups;
create policy "members read groups" on public.travel_groups
  for select to authenticated using (public.is_travel_group_member(id));
drop policy if exists "owners update groups" on public.travel_groups;
create policy "owners update groups" on public.travel_groups
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "owners delete groups" on public.travel_groups;
create policy "owners delete groups" on public.travel_groups
  for delete to authenticated using (owner_id = auth.uid());

drop policy if exists "members read memberships" on public.travel_group_members;
create policy "members read memberships" on public.travel_group_members
  for select to authenticated using (public.is_travel_group_member(group_id));
drop policy if exists "members leave or owners remove memberships" on public.travel_group_members;
create policy "members leave or owners remove memberships" on public.travel_group_members
  for delete to authenticated
  using (user_id = auth.uid() or public.is_travel_group_owner(group_id));

drop policy if exists "members read invites" on public.travel_group_invites;
create policy "members read invites" on public.travel_group_invites
  for select to authenticated using (public.is_travel_group_member(group_id));
drop policy if exists "owners update invites" on public.travel_group_invites;
create policy "owners update invites" on public.travel_group_invites
  for update to authenticated using (public.is_travel_group_owner(group_id))
  with check (public.is_travel_group_owner(group_id));

drop policy if exists "members read itineraries" on public.travel_itineraries;
create policy "members read itineraries" on public.travel_itineraries
  for select to authenticated using (public.is_travel_group_member(group_id));
drop policy if exists "members add own itineraries" on public.travel_itineraries;
create policy "members add own itineraries" on public.travel_itineraries
  for insert to authenticated
  with check (owner_id = auth.uid() and public.is_travel_group_member(group_id));
drop policy if exists "authors update itineraries" on public.travel_itineraries;
create policy "authors update itineraries" on public.travel_itineraries
  for update to authenticated
  using (owner_id = auth.uid() or public.is_travel_group_owner(group_id))
  with check (public.is_travel_group_member(group_id));
drop policy if exists "authors delete itineraries" on public.travel_itineraries;
create policy "authors delete itineraries" on public.travel_itineraries
  for delete to authenticated
  using (owner_id = auth.uid() or public.is_travel_group_owner(group_id));

create or replace function public.create_trip_group(
  p_name text,
  p_trip_id text,
  p_description text default null
)
returns table(group_id uuid, invite_code text)
language plpgsql security definer
set search_path = public, extensions
as $$
declare
  created_id uuid;
  created_code text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if nullif(trim(p_name), '') is null or nullif(trim(p_trip_id), '') is null then
    raise exception 'invalid_trip_group';
  end if;

  created_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.travel_groups(name, owner_id, trip_id, description)
  values (trim(p_name), auth.uid(), trim(p_trip_id), nullif(trim(coalesce(p_description, '')), ''))
  returning id into created_id;

  insert into public.travel_group_members(group_id, user_id, role)
  values (created_id, auth.uid(), 'owner')
  on conflict on constraint travel_group_members_pkey do update set role = 'owner';

  insert into public.travel_group_invites(group_id, code_hash, invite_code, enabled)
  values (created_id, encode(digest(lower(created_code), 'sha256'), 'hex'), created_code, true)
  on conflict on constraint travel_group_invites_pkey do update
  set code_hash = excluded.code_hash, invite_code = excluded.invite_code,
      enabled = true, created_at = now();

  return query select created_id, created_code;
end;
$$;

create or replace function public.list_my_travel_groups()
returns table(
  group_id uuid, group_name text, trip_id text, description text,
  owner_id uuid, my_role text, member_count bigint, invite_code text,
  created_at timestamptz, updated_at timestamptz
)
language sql stable security definer
set search_path = public
as $$
  select g.id, g.name, g.trip_id, g.description, g.owner_id, m.role,
    (select count(*) from public.travel_group_members c where c.group_id = g.id),
    i.invite_code, g.created_at, g.updated_at
  from public.travel_group_members m
  join public.travel_groups g on g.id = m.group_id
  left join public.travel_group_invites i on i.group_id = g.id and i.enabled
  where m.user_id = auth.uid()
  order by g.updated_at desc, g.created_at desc;
$$;

create or replace function public.get_travel_group_members(p_group_id uuid)
returns table(user_id uuid, role text, joined_at timestamptz, display_name text, email text)
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if not public.is_travel_group_member(p_group_id) then raise exception 'group_access_denied'; end if;
  return query
  select m.user_id, m.role::text, m.joined_at,
    coalesce(
      nullif(u.raw_user_meta_data->>'full_name', ''),
      nullif(u.raw_user_meta_data->>'name', ''),
      nullif(split_part(u.email, '@', 1), ''),
      '멤버'
    ),
    case
      when public.is_travel_group_owner(p_group_id) or m.user_id = auth.uid()
      then u.email::text
      else null
    end
  from public.travel_group_members m
  join auth.users u on u.id = m.user_id
  where m.group_id = p_group_id
  order by case when m.role = 'owner' then 0 else 1 end, m.joined_at;
end;
$$;

create or replace function public.rotate_travel_group_invite(p_group_id uuid)
returns text
language plpgsql security definer
set search_path = public, extensions
as $$
declare new_code text;
begin
  if not public.is_travel_group_owner(p_group_id) then raise exception 'group_owner_required'; end if;
  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.travel_group_invites(group_id, code_hash, invite_code, enabled)
  values (p_group_id, encode(digest(lower(new_code), 'sha256'), 'hex'), new_code, true)
  on conflict on constraint travel_group_invites_pkey do update
  set code_hash = excluded.code_hash, invite_code = excluded.invite_code,
      enabled = true, created_at = now();
  update public.travel_groups set updated_at = now() where id = p_group_id;
  return new_code;
end;
$$;

create or replace function public.update_travel_group(
  p_group_id uuid, p_name text, p_description text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_travel_group_owner(p_group_id) then raise exception 'group_owner_required'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'invalid_trip_group'; end if;
  update public.travel_groups
  set name = trim(p_name), description = nullif(trim(coalesce(p_description, '')), ''), updated_at = now()
  where id = p_group_id;
end;
$$;

create or replace function public.leave_travel_group(p_group_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if public.is_travel_group_owner(p_group_id) then raise exception 'owner_cannot_leave'; end if;
  delete from public.travel_group_members where group_id = p_group_id and user_id = auth.uid();
end;
$$;

create or replace function public.remove_travel_group_member(p_group_id uuid, p_user_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_travel_group_owner(p_group_id) then raise exception 'group_owner_required'; end if;
  if p_user_id = auth.uid() then raise exception 'owner_cannot_remove_self'; end if;
  delete from public.travel_group_members where group_id = p_group_id and user_id = p_user_id and role <> 'owner';
  update public.travel_groups set updated_at = now() where id = p_group_id;
end;
$$;

create or replace function public.delete_travel_group(p_group_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.is_travel_group_owner(p_group_id) then raise exception 'group_owner_required'; end if;
  delete from public.travel_groups where id = p_group_id;
end;
$$;

create or replace function public.join_travel_group(p_code text)
returns uuid
language plpgsql security definer
set search_path = public, extensions
as $$
declare joined_group_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select group_id into joined_group_id
  from public.travel_group_invites
  where enabled and code_hash = encode(digest(lower(trim(p_code)), 'sha256'), 'hex');
  if joined_group_id is null then raise exception 'invalid_group_code'; end if;
  insert into public.travel_group_members(group_id, user_id, role)
  values (joined_group_id, auth.uid(), 'member') on conflict do nothing;
  update public.travel_groups set updated_at = now() where id = joined_group_id;
  return joined_group_id;
end;
$$;

revoke all on function public.create_trip_group(text, text, text) from public;
revoke all on function public.list_my_travel_groups() from public;
revoke all on function public.get_travel_group_members(uuid) from public;
revoke all on function public.rotate_travel_group_invite(uuid) from public;
revoke all on function public.update_travel_group(uuid, text, text) from public;
revoke all on function public.leave_travel_group(uuid) from public;
revoke all on function public.remove_travel_group_member(uuid, uuid) from public;
revoke all on function public.delete_travel_group(uuid) from public;
revoke all on function public.join_travel_group(text) from public;

grant execute on function public.create_trip_group(text, text, text) to authenticated;
grant execute on function public.list_my_travel_groups() to authenticated;
grant execute on function public.get_travel_group_members(uuid) to authenticated;
grant execute on function public.rotate_travel_group_invite(uuid) to authenticated;
grant execute on function public.update_travel_group(uuid, text, text) to authenticated;
grant execute on function public.leave_travel_group(uuid) to authenticated;
grant execute on function public.remove_travel_group_member(uuid, uuid) to authenticated;
grant execute on function public.delete_travel_group(uuid) to authenticated;
grant execute on function public.join_travel_group(text) to authenticated;
