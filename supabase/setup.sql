-- הגדרת מסד הנתונים לשעון הנוכחות.
-- מדביקים את כל הקובץ ב-Supabase: SQL Editor ← New query ← Run. מריצים פעם אחת.

-- כל הנתונים של כל עסק: הגדרות, עובדים, משמרות, סידורי עבודה.
-- כל שורה שייכת לבעל עסק אחד (owner), וכל בעל עסק רואה רק את השורות שלו.
create table if not exists public.records (
  owner      uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  kind       text        not null,              -- settings / employee / shift / schedule / deleted
  id         text        not null,
  data       jsonb,
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (owner, kind, id)
);
create index if not exists records_owner_updated on public.records (owner, updated_at);

alter table public.records enable row level security;
drop policy if exists "owner only" on public.records;
create policy "owner only" on public.records
  for all to authenticated
  using (owner = auth.uid())
  with check (owner = auth.uid());

-- זמן העדכון נקבע תמיד לפי שעון השרת (לסנכרון בין מכשירים)
create or replace function public.records_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists records_touch on public.records;
create trigger records_touch before insert or update on public.records
  for each row execute function public.records_touch();

-- מסמכי עובדים (צילומי ת"ז, חוזים): אחסון פרטי, כל בעל עסק בתיקייה משלו
insert into storage.buckets (id, name, public)
values ('docs', 'docs', false)
on conflict (id) do update set public = false;

drop policy if exists "docs owner select" on storage.objects;
drop policy if exists "docs owner insert" on storage.objects;
drop policy if exists "docs owner update" on storage.objects;
drop policy if exists "docs owner delete" on storage.objects;
create policy "docs owner select" on storage.objects for select to authenticated
  using (bucket_id = 'docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "docs owner insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "docs owner update" on storage.objects for update to authenticated
  using (bucket_id = 'docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "docs owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'docs' and (storage.foldername(name))[1] = auth.uid()::text);
