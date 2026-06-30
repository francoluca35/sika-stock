-- Eliminar usuario (ADMIN / SUPERADMIN) y sus órdenes de trabajo / pedidos asociados.

create or replace function public.admin_delete_user (p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
	v_caller_id uuid;
	v_caller_rol text;
	v_target_rol text;
begin
	v_caller_id := auth.uid ();
	if v_caller_id is null then
		raise exception 'Sin sesión';
	end if;

	perform set_config ('row_security', 'off', true);

	select p.rol
	into v_caller_rol
	from public.profiles as p
	where p.id = v_caller_id;

	if v_caller_rol is null or v_caller_rol not in ('ADMIN', 'SUPERADMIN') then
		raise exception 'Forbidden';
	end if;

	if p_user_id = v_caller_id then
		raise exception 'No podés eliminar tu propia cuenta';
	end if;

	select p.rol
	into v_target_rol
	from public.profiles as p
	where p.id = p_user_id;

	if v_target_rol is null then
		raise exception 'Usuario no encontrado';
	end if;

	if v_target_rol in ('ADMIN', 'SUPERADMIN') and v_caller_rol <> 'SUPERADMIN' then
		raise exception 'Solo SUPERADMIN puede eliminar usuarios con rol ADMIN o SUPERADMIN';
	end if;

	-- Órdenes de trabajo creadas por el usuario (cascada: asignaciones, respuestas, avisos).
	delete from public.work_orders
	where created_by = p_user_id;

	-- Asignaciones a OT de otros usuarios.
	delete from public.work_order_assignments
	where user_id = p_user_id;

	-- Pedidos de mantenimiento creados por el usuario (cascada: avisos, solicitudes a compras).
	delete from public.maintenance_orders
	where created_by = p_user_id;

	-- Solicitudes Pañol→Compras registradas por el usuario (pedidos de terceros).
	delete from public.compras_panol_stock_requests
	where panol_user_id = p_user_id;

	-- Pedidos donde solo figuraba como supervisor (no se borran, se desvincula).
	update public.maintenance_orders
	set
		supervisor_id = null,
		supervisor_decided_at = null,
		supervisor_note = null
	where supervisor_id = p_user_id;

	delete from auth.users
	where id = p_user_id;
end;
$$;

comment on function public.admin_delete_user (uuid) is
	'Elimina usuario y sus OT/pedidos creados; desvincula supervisoría en pedidos ajenos.';

revoke all on function public.admin_delete_user (uuid) from public;
grant execute on function public.admin_delete_user (uuid) to authenticated;
