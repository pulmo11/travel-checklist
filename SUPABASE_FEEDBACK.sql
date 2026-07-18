-- Festival Passport feedback inbox and private screenshot storage.
-- Run once in Supabase Dashboard > SQL Editor.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('bug', 'feature', 'question', 'other')),
  title text not null check (char_length(title) between 2 and 100),
  message text not null check (char_length(message) between 10 and 3000),
  email text not null check (char_length(email) <= 254 and email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  screenshot_paths text[] not null default '{}',
  page_path text check (page_path is null or char_length(page_path) <= 500),
  referrer text check (referrer is null or char_length(referrer) <= 1000),
  user_agent text check (user_agent is null or char_length(user_agent) <= 1000),
  language text check (language is null or char_length(language) <= 50),
  screen_size text check (screen_size is null or char_length(screen_size) <= 30),
  viewport_size text check (viewport_size is null or char_length(viewport_size) <= 30),
  online boolean,
  app_version text check (app_version is null or char_length(app_version) <= 50),
  user_id uuid null,
  is_logged_in boolean not null default false,
  status text not null default 'new' check (status in ('new', 'checking', 'resolved', 'closed')),
  created_at timestamptz not null default now(),
  check (coalesce(array_length(screenshot_paths, 1), 0) <= 3),
  check ((is_logged_in and user_id is not null) or (not is_logged_in and user_id is null))
);

alter table public.feedback enable row level security;

drop policy if exists "feedback_insert_only" on public.feedback;
create policy "feedback_insert_only"
on public.feedback
for insert
to anon, authenticated
with check (
  type in ('bug', 'feature', 'question', 'other')
  and char_length(title) between 2 and 100
  and char_length(message) between 10 and 3000
  and char_length(email) <= 254
  and coalesce(array_length(screenshot_paths, 1), 0) <= 3
  and status = 'new'
  and ((is_logged_in and user_id = auth.uid()) or (not is_logged_in and user_id is null))
);

-- No SELECT, UPDATE, or DELETE policy is created for anon/authenticated clients.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feedback-images', 'feedback-images', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "feedback_images_insert_only" on storage.objects;
create policy "feedback_images_insert_only"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'feedback-images'
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
);

-- The bucket stays private. No SELECT, UPDATE, or DELETE policy is created.
-- Project administrators can inspect rows and images in Supabase Dashboard.
