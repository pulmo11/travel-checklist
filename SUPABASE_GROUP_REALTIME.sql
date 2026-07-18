-- Festival Passport group itinerary live updates.
-- Safe to run more than once in the Supabase SQL editor.

do $$
begin
  alter publication supabase_realtime add table public.travel_itineraries;
exception
  when duplicate_object then null;
end
$$;

alter table public.travel_itineraries replica identity full;
