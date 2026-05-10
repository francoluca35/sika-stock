-- Recursión infinita en políticas de `profiles`: esta migración
-- 1) Elimina todas las políticas de la tabla (por nombre en pg_policies).
-- 2) Crea políticas solo con JWT sub (sin subconsultas a `profiles`).
-- 3) Expone `get_my_profile()` como SECURITY DEFINER para leer la propia fila sin pasar por RLS.

grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;

do $$
declare
	p text;
begin
	for p in
		select policyname
		from pg_policies
		where schemaname = 'public'
			and tablename = 'profiles'
	loop
		execute format('drop policy if exists %I on public.profiles', p);
	end loop;
end $$;

create policy "profiles_select_own"
	on public.profiles for select to authenticated
	using (
		id = (select (auth.jwt () ->> 'sub')::uuid)
	);

create policy "profiles_insert_own"
	on public.profiles for insert to authenticated
	with check (
		id = (select (auth.jwt () ->> 'sub')::uuid)
	);

create policy "profiles_update_own"
	on public.profiles for update to authenticated
	using (
		id = (select (auth.jwt () ->> 'sub')::uuid)
	)
	with check (
		id = (select (auth.jwt () ->> 'sub')::uuid)
	);

-- Lectura del perfil propio: SECURITY DEFINER + row_security off en la transacción
-- evita re-evaluar políticas que provocaban recursión (42P17).
create or replace function public.get_my_profile ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
	j jsonb;
begin
	perform set_config ('row_security', 'off', true);
	select to_jsonb (p.*)
	into j
	from public.profiles as p
	where p.id = (select auth.uid ())
	limit 1;
	return j;
end;
$$;

comment on function public.get_my_profile () is 'Perfil del usuario JWT actual; usa SECURITY DEFINER para evitar recursión RLS en lecturas.';

revoke all on function public.get_my_profile () from public;
grant execute on function public.get_my_profile () to authenticated;
