-- Etapa 1: al confirmar retiro con stock, descontar `stock_items` y guardar la línea en la OM.

alter table public.maintenance_orders
	add column if not exists stock_item_id uuid references public.stock_items (id) on delete set null;

comment on column public.maintenance_orders.stock_item_id is 'Ítem de inventario descontado al confirmar retiro con stock (supervisor).';

-- -----------------------------------------------------------------------------
-- RPC atómico: decisión del supervisor + descuento de inventario si hay stock.
-- -----------------------------------------------------------------------------
create or replace function public.supervisor_decide_stock_with_inventory (
	p_order_id uuid,
	p_hay_stock boolean,
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
	v_uid uuid := auth.uid ();
	v_st int;
	v_mo int;
begin
	if v_uid is null then
		raise exception 'not authenticated';
	end if;

	if not exists (
		select 1
		from public.profiles p
		where
			p.id = v_uid
			and p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
	) then
		raise exception 'forbidden';
	end if;

	select mo.quantity, mo.workflow_status
	into strict v_qty, v_wf
	from public.maintenance_orders mo
	where
		mo.id = p_order_id
	for update;

	if v_wf is distinct from 'pending_supervisor' then
		raise exception 'invalid workflow_status';
	end if;

	if p_hay_stock then
		if p_stock_item_id is null then
			raise exception 'stock_item_id required when confirming stock';
		end if;

		update public.stock_items si
		set cantidad = si.cantidad - v_qty
		where
			si.id = p_stock_item_id
			and si.cantidad >= v_qty;

		get diagnostics v_st = row_count;

		if v_st <> 1 then
			raise exception 'insufficient stock or invalid stock_item_id';
		end if;

		update public.maintenance_orders mo
		set
			workflow_status = 'supervisor_stock_ok',
			stock_item_id = p_stock_item_id,
			supervisor_id = v_uid,
			supervisor_decided_at = timezone ('utc', now ()),
			updated_at = timezone ('utc', now ())
		where
			mo.id = p_order_id
			and mo.workflow_status = 'pending_supervisor';

		get diagnostics v_mo = row_count;

		if v_mo <> 1 then
			raise exception 'maintenance_orders concurrent update';
		end if;
	else
		update public.maintenance_orders mo
		set
			workflow_status = 'forwarded_to_panol',
			supervisor_id = v_uid,
			supervisor_decided_at = timezone ('utc', now ()),
			updated_at = timezone ('utc', now ())
		where
			mo.id = p_order_id
			and mo.workflow_status = 'pending_supervisor';

		get diagnostics v_mo = row_count;

		if v_mo <> 1 then
			raise exception 'maintenance_orders concurrent update';
		end if;
	end if;
end;
$$;

comment on function public.supervisor_decide_stock_with_inventory (uuid, boolean, uuid) is
	'Supervisor: pending_supervisor → supervisor_stock_ok (descuenta stock) o forwarded_to_panol.';

grant execute on function public.supervisor_decide_stock_with_inventory (uuid, boolean, uuid) to authenticated;
