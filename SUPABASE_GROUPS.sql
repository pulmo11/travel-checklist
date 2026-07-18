create extension if not exists pgcrypto;

create table if not exists public.travel_groups (
  id uuid primary key default gen_random_uuid(), name text not null check (char_length(name) between 1 and 50),
  owner_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now()
);
create table if not exists public.travel_group_members (
  group_id uuid not null references public.travel_groups(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member','viewer')), joined_at timestamptz not null default now(), primary key (group_id,user_id)
);
create table if not exists public.travel_group_invites (
  group_id uuid primary key references public.travel_groups(id) on delete cascade, code_hash text not null unique,
  enabled boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.travel_itineraries (
  id uuid primary key default gen_random_uuid(), group_id uuid not null references public.travel_groups(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade, traveler_name text not null check (char_length(traveler_name) between 1 and 30),
  kind text not null check (kind in ('flight','train','car','other')), direction text, carrier text, depart_at timestamptz, arrive_at timestamptz,
  from_label text not null default '', to_label text not null default '', from_detail text, to_detail text, note text, created_at timestamptz not null default now()
);

alter table public.travel_groups enable row level security;
alter table public.travel_group_members enable row level security;
alter table public.travel_group_invites enable row level security;
alter table public.travel_itineraries enable row level security;

create or replace function public.is_travel_group_member(p_group_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.travel_group_members where group_id=p_group_id and user_id=auth.uid()) $$;
create or replace function public.is_travel_group_owner(p_group_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.travel_groups where id=p_group_id and owner_id=auth.uid()) $$;

drop policy if exists "members read groups" on public.travel_groups;
create policy "members read groups" on public.travel_groups for select to authenticated using (public.is_travel_group_member(id));
drop policy if exists "members read memberships" on public.travel_group_members;
create policy "members read memberships" on public.travel_group_members for select to authenticated using (public.is_travel_group_member(group_id));
drop policy if exists "members read itineraries" on public.travel_itineraries;
create policy "members read itineraries" on public.travel_itineraries for select to authenticated using (public.is_travel_group_member(group_id));
drop policy if exists "members add own itineraries" on public.travel_itineraries;
create policy "members add own itineraries" on public.travel_itineraries for insert to authenticated with check (owner_id=auth.uid() and public.is_travel_group_member(group_id));
drop policy if exists "authors update itineraries" on public.travel_itineraries;
create policy "authors update itineraries" on public.travel_itineraries for update to authenticated using (owner_id=auth.uid() or public.is_travel_group_owner(group_id)) with check (public.is_travel_group_member(group_id));
drop policy if exists "authors delete itineraries" on public.travel_itineraries;
create policy "authors delete itineraries" on public.travel_itineraries for delete to authenticated using (owner_id=auth.uid() or public.is_travel_group_owner(group_id));

create or replace function public.create_travel_group(p_name text)
returns table(group_id uuid,invite_code text) language plpgsql security definer set search_path=public,extensions
as $$
declare v_group_id uuid; v_code text:=upper(encode(gen_random_bytes(6),'hex')); v_private jsonb; v_flight jsonb; v_person record; v_move jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  insert into public.travel_groups(name,owner_id) values(trim(p_name),auth.uid()) returning id into v_group_id;
  insert into public.travel_group_members(group_id,user_id,role) values(v_group_id,auth.uid(),'owner');
  insert into public.travel_group_invites(group_id,code_hash) values(v_group_id,encode(digest(lower(v_code),'sha256'),'hex'));
  select private_data into v_private from public.travel_companion_data where user_id=auth.uid();
  for v_flight in select value from jsonb_array_elements(coalesce(v_private->'flights','[]'::jsonb)) loop
    insert into public.travel_itineraries(group_id,owner_id,traveler_name,kind,direction,carrier,depart_at,arrive_at,from_label,to_label,from_detail,to_detail,note)
    values(v_group_id,auth.uid(),v_flight->>'name','flight',v_flight->>'direction',v_flight->>'airline',nullif(v_flight->>'depart','')::timestamptz,nullif(v_flight->>'arrive','')::timestamptz,v_flight->>'from',v_flight->>'to',v_flight->>'fromDetail',v_flight->>'toDetail',case when coalesce((v_flight->>'timeUnknown')::boolean,false) then '시간 미등록' end);
  end loop;
  for v_person in select key,value from jsonb_each(coalesce(v_private->'movement','{}'::jsonb)) loop
    for v_move in select value from jsonb_array_elements(v_person.value) loop
      insert into public.travel_itineraries(group_id,owner_id,traveler_name,kind,from_label,to_label,note)
      values(v_group_id,auth.uid(),v_person.key,case when v_move->>'value' like '%신칸센%' then 'train' when v_move->>'value' like '%렌터카%' then 'car' else 'other' end,coalesce(v_move->>'label','이동'),' ',v_move->>'value');
    end loop;
  end loop;
  return query select v_group_id,v_code;
end $$;

create or replace function public.join_travel_group(p_code text)
returns uuid language plpgsql security definer set search_path=public,extensions
as $$
declare v_group_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select group_id into v_group_id from public.travel_group_invites where enabled and code_hash=encode(digest(lower(trim(p_code)),'sha256'),'hex');
  if v_group_id is null then raise exception 'invalid_group_code'; end if;
  insert into public.travel_group_members(group_id,user_id,role) values(v_group_id,auth.uid(),'member') on conflict do nothing;
  return v_group_id;
end $$;

revoke all on function public.create_travel_group(text) from public;
revoke all on function public.join_travel_group(text) from public;
grant execute on function public.create_travel_group(text) to authenticated;
grant execute on function public.join_travel_group(text) to authenticated;
grant select on public.travel_groups to authenticated;
grant select on public.travel_group_members to authenticated;
grant select,insert,update,delete on public.travel_itineraries to authenticated;
