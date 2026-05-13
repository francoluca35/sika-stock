-- Pañol: actualizar cantidad en inventario y marcar pedido listo para retiro (con stock_item_id).

create or replace function public.panol_confirm_stock_with_inventory (
	p_order_id uuid,
	p_stock_item_id uuid,
	p_cantidad int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
	v_uid uuid := auth.uid ();
	v_wf text;
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
			and p.rol = 'PANOL'
	) then
		raise exception 'forbidden';
	end if;

	if p_cantidad is null or p_cantidad < 1 then
		raise exception 'invalid cantidad';
	end if;

	select mo.workflow_status
	into strict v_wf
	from public.maintenance_orders mo
	where
		mo.id = p_order_id
	for update;

	if v_wf is distinct from 'forwarded_to_panol' then
		raise exception 'invalid workflow_status';
	end if;

	update public.stock_items si
	set cantidad = p_cantidad
	where
		si.id = p_stock_item_id;

	get diagnostics v_st = row_count;

	if v_st <> 1 then
		raise exception 'invalid stock_item_id';
	end if;

	update public.maintenance_orders mo
	set
		workflow_status = 'supervisor_stock_ok',
		stock_item_id = p_stock_item_id,
		updated_at = timezone ('utc', now ())
	where
		mo.id = p_order_id
		and mo.workflow_status = 'forwarded_to_panol';

	get diagnostics v_mo = row_count;

	if v_mo <> 1 then
		raise exception 'maintenance_orders concurrent update';
	end if;
end;
$$;

comment on function public.panol_confirm_stock_with_inventory (uuid, uuid, int) is
	'Pañol: forwarded_to_panol → supervisor_stock_ok; fija cantidad en stock_items y vincula stock_item_id.';

grant execute on function public.panol_confirm_stock_with_inventory (uuid, uuid, int) to authenticated;

-- Notificación según si el hallazgo quedó vinculado al catálogo digital o no.
create or replace function public.trg_mo_after_update_panol_stock_externo_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_kind text;
	v_body text;
begin
	if tg_op <> 'UPDATE' then
		return new;
	end if;

	if old.workflow_status = 'forwarded_to_panol'
	and new.workflow_status = 'supervisor_stock_ok' then
		if new.stock_item_id is not null then
			v_kind := 'stock_ok_retiro';
			v_body := concat_ws (
				' · ',
				coalesce (new.order_number, ''),
				coalesce (new.product_name, ''),
				'Pañol registró stock en inventario; coordinar retiro.'
			);
		else
			v_kind := 'panol_stock_externo';
			v_body := concat_ws (
				' · ',
				coalesce (new.order_number, ''),
				coalesce (new.product_name, ''),
				'Pañol confirmó stock fuera del inventario del sistema; coordinar retiro.'
			);
		end if;

		insert into public.maintenance_order_notifications (
			user_id,
			order_id,
			kind,
			title,
			body
		)
		select distinct
			u.uid,
			new.id,
			v_kind,
			case
				when v_kind = 'stock_ok_retiro' then 'Pañol: stock disponible'
				else 'Pañol: material disponible'
			end,
			v_body
		from (
			select p.id as uid
			from public.profiles p
			where
				p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
			union
			select mo.created_by
			from public.maintenance_orders mo
			where
				mo.id = new.id
		) u
		where
			u.uid is not null;
	end if;

	return new;
end;
$$;
