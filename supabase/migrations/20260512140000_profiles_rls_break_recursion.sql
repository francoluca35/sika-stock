-- Error 42P17: infinite recursion detected in policy for relation "profiles"
-- Suele haber políticas extra que consultan `profiles` dentro del USING (p. ej. EXISTS (...)).
-- Esta migración borra TODAS las políticas de `profiles` y deja solo fila propia vía auth.uid().

grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;

do $$
declare
	p record;
begin
	for p in
		select policyname
		from pg_policies
		where schemaname = 'public'
			and tablename = 'profiles'
	loop
		execute format('drop policy if exists %I on public.profiles', p.policyname);
	end loop;
end $$;

create policy "profiles_select_own"
	on public.profiles for select to authenticated
	using (auth.uid () = id);

create policy "profiles_insert_own"
	on public.profiles for insert to authenticated
	with check (auth.uid () = id);

create policy "profiles_update_own"
	on public.profiles for update to authenticated
	using (auth.uid () = id)
	with check (auth.uid () = id);
