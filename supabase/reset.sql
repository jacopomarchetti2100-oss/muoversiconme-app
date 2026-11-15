-- =====================================================================
-- AZZERA lo schema dell'area clienti (cancella tabelle, dati e regole).
-- Usalo solo durante la beta, se schema.sql si è fermato a metà.
-- Poi esegui di nuovo schema.sql.
-- I video già caricati nello storage vanno cancellati a mano
-- (Storage → video → seleziona tutto → Delete) prima di eseguire questo.
-- =====================================================================

-- tempo reale
do $$ begin
  alter publication supabase_realtime drop table public.messaggi, public.video;
exception when others then null; end $$;

-- regole dello storage
drop policy if exists "storage: leggo i miei video, il coach tutti" on storage.objects;
drop policy if exists "storage: carico nella mia cartella" on storage.objects;
drop policy if exists "storage: sostituisco i miei" on storage.objects;
drop policy if exists "storage: cancello i miei, il coach tutti" on storage.objects;
-- la cartella "video" resta: schema.sql la riusa

-- trigger e funzioni
drop trigger if exists al_nuovo_utente on auth.users;
drop function if exists public.nuovo_profilo() cascade;

-- tabelle (con le loro regole)
drop table if exists public.messaggi cascade;
drop table if exists public.video cascade;
drop table if exists public.esercizi cascade;
drop table if exists public.profili cascade;
drop function if exists public.sono_coach() cascade;
