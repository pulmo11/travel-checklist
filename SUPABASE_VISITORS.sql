create table if not exists public.site_visitors (
  visitor_hash text primary key,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now()
);

create table if not exists public.site_daily_visitors (
  visit_day date not null,
  visitor_hash text not null,
  first_seen timestamptz not null default now(),
  primary key (visit_day, visitor_hash)
);

alter table public.site_visitors enable row level security;
alter table public.site_daily_visitors enable row level security;

create or replace function public.record_site_visit(p_visitor_token text)
returns table(daily_visitors bigint, total_visitors bigint)
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  v_hash text;
  v_day date := (now() at time zone 'Asia/Seoul')::date;
begin
  if p_visitor_token is null or char_length(p_visitor_token) < 16 or char_length(p_visitor_token) > 100 then
    raise exception 'invalid_visitor_token';
  end if;
  v_hash := encode(digest(p_visitor_token, 'sha256'), 'hex');
  insert into public.site_visitors(visitor_hash) values(v_hash)
    on conflict(visitor_hash) do update set last_seen=now();
  insert into public.site_daily_visitors(visit_day,visitor_hash) values(v_day,v_hash)
    on conflict do nothing;
  return query
    select
      (select count(*) from public.site_daily_visitors where visit_day=v_day),
      (select count(*) from public.site_visitors);
end $$;

revoke all on table public.site_visitors from anon,authenticated;
revoke all on table public.site_daily_visitors from anon,authenticated;
revoke all on function public.record_site_visit(text) from public;
grant execute on function public.record_site_visit(text) to anon,authenticated;
