-- AtollCard — Contact avatar photo.
--
-- Adds `avatar_url` to `contacts` so each person can have one portrait
-- shared across all their persona cards. The image itself lives in the
-- public-read `contact-avatars` Storage bucket at the path
-- `<contact_id>.jpg` (the iOS app uploads with overwrite semantics so
-- there's never more than one photo per person).
--
-- Read access:
--   • `avatar_url` is already SELECT-able for anon via the policy
--     installed in migration 0098 (public-read of contacts), so the
--     /c/<slug> page can render the photo without extra rules.
--   • The Storage bucket is created with `public = true` so the public
--     CDN URL works in <img src> without signed URLs.
--
-- Write access:
--   • Only the auth-user owner can UPDATE their own contact row
--     (existing RLS on contacts).
--   • Storage write policies below restrict uploads to the user's own
--     `<contact_id>.jpg` key.

-- ─── Column ──────────────────────────────────────────────────────────
alter table public.contacts
  add column if not exists avatar_url text;

comment on column public.contacts.avatar_url is
  'Public-CDN URL of the contact''s portrait photo, stored in the contact-avatars Storage bucket. NULL = render initials fallback on AtollCard.';

-- ─── Storage bucket ──────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'contact-avatars',
  'contact-avatars',
  true,                              -- public-read via CDN
  2 * 1024 * 1024,                   -- 2 MB cap
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public            = excluded.public,
  file_size_limit   = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ─── Storage policies ────────────────────────────────────────────────
-- Public read: anyone can GET an object from the bucket.
drop policy if exists "contact_avatars_public_read" on storage.objects;
create policy "contact_avatars_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'contact-avatars');

-- Authenticated upload: a signed-in user may write `<contact_id>.<ext>`
-- only if that contact is theirs (linked through contact_instructor).
drop policy if exists "contact_avatars_owner_write" on storage.objects;
create policy "contact_avatars_owner_write"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'contact-avatars'
    and exists (
      select 1
      from public.contact_instructor ci
      where ci.auth_user_id = auth.uid()
        and ci.contact_id::text = split_part(storage.objects.name, '.', 1)
    )
  );

drop policy if exists "contact_avatars_owner_update" on storage.objects;
create policy "contact_avatars_owner_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'contact-avatars'
    and exists (
      select 1
      from public.contact_instructor ci
      where ci.auth_user_id = auth.uid()
        and ci.contact_id::text = split_part(storage.objects.name, '.', 1)
    )
  );

drop policy if exists "contact_avatars_owner_delete" on storage.objects;
create policy "contact_avatars_owner_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'contact-avatars'
    and exists (
      select 1
      from public.contact_instructor ci
      where ci.auth_user_id = auth.uid()
        and ci.contact_id::text = split_part(storage.objects.name, '.', 1)
    )
  );
