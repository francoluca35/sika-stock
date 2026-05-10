-- Lista de usuarios (ADMIN/SUPERADMIN): política SELECT que incluye todas las filas
-- si can_manage_users() es true (función SECURITY DEFINER sin recursión RLS).

create or replace function public.can_manage_users ()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
	perform set_config ('row_security', 'off', true);
	return exists (
		select 1
		from public.profiles as p
		where p.id = (select auth.uid ())
			and p.rol in ('ADMIN', 'SUPERADMIN')
	);
end;
$$;

comment on function public.can_manage_users () is 'True si el JWT actual es ADMIN o SUPERADMIN en profiles; usa SECURITY DEFINER + row_security off.';

revoke all on function public.can_manage_users () from public;
grant execute on function public.can_manage_users () to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;

create policy "profiles_select_scope"
	on public.profiles for select to authenticated
	using (
		id = (select (auth.jwt () ->> 'sub')::uuid)
		or public.can_manage_users ()
	);
