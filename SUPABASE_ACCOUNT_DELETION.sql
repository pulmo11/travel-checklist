-- Festival Passport self-service account deletion.
-- Run once in Supabase Dashboard > SQL Editor before deploying delete-account.
-- Existing user and group data is preserved until a signed-in user requests deletion.

create or replace function public.delete_festival_passport_account_data()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  deleting_user uuid := auth.uid();
  owned_group record;
  joined_group record;
  successor_id uuid;
  transferred_groups integer := 0;
  deleted_solo_groups integer := 0;
  removed_memberships integer := 0;
  affected integer := 0;
begin
  if deleting_user is null then
    raise exception 'authentication_required';
  end if;

  -- Preserve a shared group by transferring it to its earliest remaining member.
  -- A group with no other member can be removed without affecting another account.
  for owned_group in
    select id
    from public.travel_groups
    where owner_id = deleting_user
    order by created_at, id
    for update
  loop
    select member.user_id
      into successor_id
    from public.travel_group_members member
    where member.group_id = owned_group.id
      and member.user_id <> deleting_user
    order by member.joined_at, member.user_id
    limit 1;

    if successor_id is null then
      delete from public.travel_groups where id = owned_group.id;
      deleted_solo_groups := deleted_solo_groups + 1;
    else
      update public.travel_group_members
        set role = 'owner'
        where group_id = owned_group.id and user_id = successor_id;
      update public.travel_groups
        set owner_id = successor_id, updated_at = now()
        where id = owned_group.id;
      update public.travel_itineraries
        set owner_id = successor_id
        where group_id = owned_group.id and owner_id = deleting_user;
      delete from public.travel_group_members
        where group_id = owned_group.id and user_id = deleting_user;
      transferred_groups := transferred_groups + 1;
      removed_memberships := removed_memberships + 1;
    end if;
  end loop;

  -- Schedules authored by a departing member remain shared. Their ownership moves
  -- to the group owner before only the departing user's membership is removed.
  for joined_group in
    select member.group_id, trip_group.owner_id
    from public.travel_group_members member
    join public.travel_groups trip_group on trip_group.id = member.group_id
    where member.user_id = deleting_user
      and trip_group.owner_id <> deleting_user
    for update of member, trip_group
  loop
    update public.travel_itineraries
      set owner_id = joined_group.owner_id
      where group_id = joined_group.group_id and owner_id = deleting_user;
    delete from public.travel_group_members
      where group_id = joined_group.group_id and user_id = deleting_user;
    removed_memberships := removed_memberships + 1;
  end loop;

  -- Defensive cleanup for a legacy itinerary whose author membership was already
  -- removed: keep the shared row and hand it to the current group owner.
  update public.travel_itineraries itinerary
    set owner_id = trip_group.owner_id
    from public.travel_groups trip_group
    where itinerary.group_id = trip_group.id
      and itinerary.owner_id = deleting_user
      and trip_group.owner_id <> deleting_user;

  delete from public.travel_group_members where user_id = deleting_user;

  -- Delete account-owned application data. Auth deletion follows in the Edge
  -- Function; explicit deletes also cover legacy rows without an FK cascade.
  delete from public.feedback where user_id = deleting_user;
  get diagnostics affected = row_count;

  delete from public.festival_passport_device_backups where user_id = deleting_user;
  delete from public.travel_companion_data where user_id = deleting_user;
  delete from public.festival_passport_profiles where user_id = deleting_user;

  return jsonb_build_object(
    'prepared', true,
    'transferred_groups', transferred_groups,
    'deleted_solo_groups', deleted_solo_groups,
    'removed_memberships', removed_memberships,
    'deleted_feedback', affected
  );
end;
$$;

revoke all on function public.delete_festival_passport_account_data() from public;
grant execute on function public.delete_festival_passport_account_data() to authenticated;
