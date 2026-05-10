-- Evita 500 en GET /rest/v1/profiles (PostgREST) cuando faltan GRANT o las políticas
-- evalúan auth.uid() de forma problemática. Ejecutar en SQL Editor si ya tenés la BD en uso.

grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own"
	on public.profiles for select to authenticated
	using ((select auth.uid ()) = id);

create policy "profiles_insert_own"
	on public.profiles for insert to authenticated
	with check ((select auth.uid ()) = id);

create policy "profiles_update_own"
	on public.profiles for update to authenticated
	using ((select auth.uid ()) = id)
	with check ((select auth.uid ()) = id);
