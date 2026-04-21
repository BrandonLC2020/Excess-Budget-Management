-- Add full_name and avatar_url to profiles
alter table public.profiles 
add column if not exists full_name text,
add column if not exists avatar_url text;

-- Create avatars storage bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Set up RLS for avatars bucket
-- 1. Allow public access to view avatars
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'avatars' );

-- 2. Allow authenticated users to upload their own avatars
create policy "Users can upload their own avatar"
on storage.objects for insert
with check (
  bucket_id = 'avatars' AND
  (auth.uid())::text = (storage.foldername(name))[1]
);

-- 3. Allow authenticated users to update their own avatars
create policy "Users can update their own avatar"
on storage.objects for update
using (
  bucket_id = 'avatars' AND
  (auth.uid())::text = (storage.foldername(name))[1]
);

-- 4. Allow authenticated users to delete their own avatars
create policy "Users can delete their own avatar"
on storage.objects for delete
using (
  bucket_id = 'avatars' AND
  (auth.uid())::text = (storage.foldername(name))[1]
);
