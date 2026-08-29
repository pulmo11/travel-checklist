-- Festival Passport self-service account deletion (P0 hardened).
-- Personal application rows are deleted only by Auth FK cascades after the
-- Admin API successfully deletes the account.

create or replace function public.prepare_festival_passport_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_temp
as $$
declare
  deleting_user uuid := auth.uid();
  owned_group record;
  joined_group record;
  successor_id uuid;
  transferred_groups integer := 0;
  transferred_itineraries integer := 0;
  affected integer := 0;
  image_paths jsonb := '[]'::jsonb;
begin
  if deleting_user is null then
    raise exception 'authentication_required';
  end if;

  -- Transfer only shared groups. Solo groups remain owned by this account and
  -- are removed later by the existing owner_id cascade.
  for owned_group in
    select id from public.travel_groups
    where owner_id = deleting_user
    order by created_at, id
    for update
  loop
    select member.user_id into successor_id
    from public.travel_group_members member
    where member.group_id = owned_group.id and member.user_id <> deleting_user
    order by member.joined_at, member.user_id
    limit 1;

    if successor_id is not null then
      update public.travel_group_members
        set role = case when user_id = successor_id then 'owner' else 'member' end
        where group_id = owned_group.id
          and user_id in (successor_id, deleting_user);
      update public.travel_groups
        set owner_id = successor_id, updated_at = now()
        where id = owned_group.id and owner_id = deleting_user;
      update public.travel_itineraries
        set owner_id = successor_id
        where group_id = owned_group.id and owner_id = deleting_user;
      get diagnostics affected = row_count;
      transferred_itineraries := transferred_itineraries + affected;
      transferred_groups := transferred_groups + 1;
    end if;
  end loop;

  -- Keep a departing member's shared schedules with the current group owner.
  -- Membership remains until the Auth FK cascade runs.
  for joined_group in
    select member.group_id, trip_group.owner_id
    from public.travel_group_members member
    join public.travel_groups trip_group on trip_group.id = member.group_id
    where member.user_id = deleting_user and trip_group.owner_id <> deleting_user
    for update of member, trip_group
  loop
    update public.travel_itineraries
      set owner_id = joined_group.owner_id
      where group_id = joined_group.group_id and owner_id = deleting_user;
    get diagnostics affected = row_count;
    transferred_itineraries := transferred_itineraries + affected;
  end loop;

  -- Capture linked and orphan images by the actual Storage owner columns.
  select coalesce(jsonb_agg(object.name order by object.name), '[]'::jsonb)
    into image_paths
  from storage.objects object
  where object.bucket_id = 'feedback-images'
    and (object.owner = deleting_user or object.owner_id = deleting_user::text);

  return jsonb_build_object(
    'prepared', true,
    'transferred_groups', transferred_groups,
    'transferred_itineraries', transferred_itineraries,
    'image_paths', image_paths
  );
end;
$$;

revoke all on function public.prepare_festival_passport_account_deletion() from public;
grant execute on function public.prepare_festival_passport_account_deletion() to authenticated;

-- Remove the earlier destructive RPC so a session cannot delete personal rows
-- before the Auth Admin API succeeds.
drop function if exists public.delete_festival_passport_account_data();

-- Anonymous feedback keeps a null user_id. Logged-in feedback follows the Auth
-- lifecycle and is deleted by the same transaction as auth.users.
alter table public.feedback drop constraint if exists feedback_user_id_fkey;
alter table public.feedback
  add constraint feedback_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade not valid;
alter table public.feedback validate constraint feedback_user_id_fkey;

-- Return only unlinked paths owned by the current session. The Edge Function
-- removes these paths through the Storage API, including the underlying file.
create or replace function public.get_owned_unlinked_feedback_image_paths(p_paths text[])
returns text[]
language sql
security definer
set search_path = public, storage, pg_temp
as $$
  select coalesce(array_agg(object.name order by object.name), '{}'::text[])
  from storage.objects object
  where auth.uid() is not null
    and object.bucket_id = 'feedback-images'
    and object.name = any(coalesce(p_paths, '{}'::text[]))
    and (object.owner = auth.uid() or object.owner_id = auth.uid()::text)
    and not exists (
      select 1 from public.feedback item
      where object.name = any(item.screenshot_paths)
    );
$$;

revoke all on function public.get_owned_unlinked_feedback_image_paths(text[]) from public;
grant execute on function public.get_owned_unlinked_feedback_image_paths(text[]) to anon, authenticated;
