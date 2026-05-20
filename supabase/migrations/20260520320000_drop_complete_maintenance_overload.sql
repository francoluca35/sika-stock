-- PostgREST PGRST203: quitar overload de 1 arg; queda solo (uuid, uuid default null).

drop function if exists public.complete_maintenance_order_with_inventory (uuid);

create or replace function public.complete_maintenance_order_with_inventory (
	p_order_id uuid,
	p_stock_item_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
	v_qty int;
	v_wf text;
	v_stock_id uuid;
	v_deducted_at timestamptz;
	v_uid uuid := auth.uid ();
	v_st int;
	v_mo int;
	v_rol text;
begin
	if v_uid is null then
		raise exception 'not authenticated';
	end if;

	select p.rol
	into strict v_rol
	from public.profiles p
	where p.id = v_uid;

	if v_rol not in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN', 'PANOL') then
		raise exception 'forbidden';
	end if;

	select mo.quantity, mo.workflow_status, mo.stock_item_id, mo.stock_deducted_at
	into strict v_qty, v_wf, v_stock_id, v_deducted_at
	from public.maintenance_orders mo
	where
		mo.id = p_order_id
	for update;

	if v_wf not in ('supervisor_stock_ok', 'compras_arrived_notified') then
		raise exception 'invalid workflow_status';
	end if;

	if p_stock_item_id is not null then
		if not exists (
			select 1
			from public.stock_items si
			where si.id = p_stock_item_id
		) then
			raise exception 'invalid stock_item_id';
		end if;
		v_stock_id := p_stock_item_id;
	end if;

	if v_stock_id is not null and v_deducted_at is null then
		update public.stock_items si
		set cantidad = si.cantidad - v_qty
		where
			si.id = v_stock_id
			and si.cantidad >= v_qty;

		get diagnostics v_st = row_count;

		if v_st <> 1 then
			raise exception 'insufficient stock or invalid stock_item_id';
		end if;
	end if;

	update public.maintenance_orders mo
	set
		workflow_status = 'completed',
		stock_item_id = coalesce (p_stock_item_id, mo.stock_item_id),
		stock_deducted_at = coalesce (mo.stock_deducted_at, timezone ('utc', now ())),
		updated_at = timezone ('utc', now ())
	where
		mo.id = p_order_id
		and mo.workflow_status in ('supervisor_stock_ok', 'compras_arrived_notified');

	get diagnostics v_mo = row_count;

	if v_mo <> 1 then
		raise exception 'maintenance_orders concurrent update';
	end if;
end;
$$;

comment on function public.complete_maintenance_order_with_inventory (uuid, uuid) is
	'Retiro: descuenta una vez; p_stock_item_id opcional para cambiar línea antes de cerrar.';

grant execute on function public.complete_maintenance_order_with_inventory (uuid, uuid) to authenticated;
