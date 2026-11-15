-- =====================================================================
-- Muoversi con Me · Area clienti · schema database (beta)
-- Da incollare in Supabase → SQL Editor → New query → Run (una volta sola)
-- =====================================================================

-- ---------- PROFILI: uno per ogni utente (cliente o coach) ----------
create table public.profili (
  id         uuid primary key references auth.users on delete cascade,
  nome       text not null default '',
  ruolo      text not null default 'cliente' check (ruolo in ('cliente', 'coach')),
  settimana  int  not null default 1,
  obiettivo  text not null default '',
  creato_il  timestamptz not null default now()
);

-- Quando crei un utente da Authentication, il profilo nasce da solo (come cliente)
create function public.nuovo_profilo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profili (id, nome) values (new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)));
  return new;
end $$;
create trigger al_nuovo_utente after insert on auth.users
  for each row execute function public.nuovo_profilo();

-- true se chi fa la richiesta è il coach
create function public.sono_coach() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profili where id = auth.uid() and ruolo = 'coach');
$$;

-- ---------- ESERCIZI: la scheda di ogni cliente ----------
create table public.esercizi (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.profili on delete cascade,
  ordine      int  not null default 1,
  nome        text not null,
  nota        text not null default '',
  serie       text not null default '',
  recupero    text not null default ''
);

-- ---------- VIDEO: uno per esercizio (il nuovo sostituisce il vecchio) ----------
create table public.video (
  id            uuid primary key default gen_random_uuid(),
  esercizio_id  uuid not null unique references public.esercizi on delete cascade,
  cliente_id    uuid not null references public.profili on delete cascade,
  percorso      text not null,                -- posizione del file nello storage
  nome_file     text not null default '',
  peso          bigint not null default 0,
  durata        real not null default 0,
  stato         text not null default 'da-vedere' check (stato in ('da-vedere', 'visto')),
  commento      text not null default '',
  commentato_il timestamptz,
  caricato_il   timestamptz not null default now()
);

-- ---------- MESSAGGI: una chat per cliente ----------
create table public.messaggi (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.profili on delete cascade,  -- di quale chat fa parte
  autore_id   uuid not null references public.profili on delete cascade default auth.uid(),
  tipo        text not null default 'testo' check (tipo in ('testo', 'evento')),
  testo       text not null check (length(testo) between 1 and 4000),
  inviato_il  timestamptz not null default now()
);
create index on public.messaggi (cliente_id, inviato_il);

-- =====================================================================
-- REGOLE DI ACCESSO: il cliente vede solo i suoi dati, il coach tutto
-- =====================================================================
alter table public.profili  enable row level security;
alter table public.esercizi enable row level security;
alter table public.video    enable row level security;
alter table public.messaggi enable row level security;

create policy "profilo: leggo il mio, il coach tutti" on public.profili for select
  using (id = auth.uid() or public.sono_coach());
create policy "profilo: modifica solo il coach" on public.profili for update
  using (public.sono_coach());

create policy "esercizi: leggo i miei, il coach tutti" on public.esercizi for select
  using (cliente_id = auth.uid() or public.sono_coach());
create policy "esercizi: gestisce il coach" on public.esercizi for all
  using (public.sono_coach()) with check (public.sono_coach());

create policy "video: leggo i miei, il coach tutti" on public.video for select
  using (cliente_id = auth.uid() or public.sono_coach());
create policy "video: il cliente carica i suoi" on public.video for insert
  with check (cliente_id = auth.uid());
create policy "video: il cliente sostituisce i suoi, il coach commenta" on public.video for update
  using (cliente_id = auth.uid() or public.sono_coach());
create policy "video: cancella il proprietario o il coach" on public.video for delete
  using (cliente_id = auth.uid() or public.sono_coach());

create policy "chat: leggo la mia, il coach tutte" on public.messaggi for select
  using (cliente_id = auth.uid() or public.sono_coach());
create policy "chat: scrivo nella mia, il coach in tutte" on public.messaggi for insert
  with check (autore_id = auth.uid() and (cliente_id = auth.uid() or public.sono_coach()));

-- =====================================================================
-- STORAGE: cartella privata "video", ogni cliente nella sua sottocartella
-- (percorso: <id cliente>/<id esercizio>-<ora>.mp4)
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('video', 'video', false, 52428800, array['video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "storage: leggo i miei video, il coach tutti" on storage.objects for select
  using (bucket_id = 'video' and ((storage.foldername(name))[1] = auth.uid()::text or public.sono_coach()));
create policy "storage: carico nella mia cartella" on storage.objects for insert
  with check (bucket_id = 'video' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "storage: sostituisco i miei" on storage.objects for update
  using (bucket_id = 'video' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "storage: cancello i miei, il coach tutti" on storage.objects for delete
  using (bucket_id = 'video' and ((storage.foldername(name))[1] = auth.uid()::text or public.sono_coach()));

-- =====================================================================
-- TEMPO REALE: chat e stato dei video si aggiornano senza ricaricare
-- =====================================================================
alter publication supabase_realtime add table public.messaggi, public.video;
