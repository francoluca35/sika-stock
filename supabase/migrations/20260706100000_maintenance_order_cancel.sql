-- Anular pedido de mantenimiento (supervisor / pañol / admin) con observación y aviso al técnico.

alter table public.maintenance_orders
	add column if not exists cancellation_observacion text,
	add column if not exists cancelled_by uuid references public.profiles (id),
	add column if not exists cancelled_at timestamptz;

comment on column public.maintenance_orders.cancellation_observacion is
	'Motivo de anulación ingresado por supervisor, pañol o admin.';

alter table public.maintenance_order_notifications
	drop constraint if exists maintenance_order_notifications_kind_check;

alter table public.maintenance_order_notifications
	add constraint maintenance_order_notifications_kind_check
		check (
			kind in (
				'stock_ok_retiro',
				'derivado_panol',
				'panol_atento_retiro',
				'derivado_panol_panol',
				'panol_stock_externo',
				'enviado_a_compras',
				'oc_emitida_compras',
				'compra_realizada',
				'material_llego_planta',
				'sin_stock_pendiente',
				'pedido_anulado'
			)
		);

create or replace function public.cancel_maintenance_order (
	p_order_id uuid,
	p_observacion text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
	v_uid uuid := auth.uid ();
	v_rol text;
	v_wf text;
	v_qty int;
	v_stock_id uuid;
	v_deducted_at timestamptz;
	v_created_by uuid;
	v_order_number text;
	v_product_name text;
	v_obs text;
	v_mo int;
	v_st int;
begin
	if v_uid is null then
		raise exception 'not authenticated';
	end if;

	v_obs := nullif (trim (coalesce (p_observacion, '')), '');

	if v_obs is null then
		raise exception 'observacion required';
	end if;

	select p.rol
	into strict v_rol
	from public.profiles p
	where p.id = v_uid;

	if v_rol not in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN', 'PANOL') then
		raise exception 'forbidden';
	end if;

	select
		mo.workflow_status,
		mo.quantity,
		mo.stock_item_id,
		mo.stock_deducted_at,
		mo.created_by,
		mo.order_number,
		mo.product_name
	into strict
		v_wf,
		v_qty,
		v_stock_id,
		v_deducted_at,
		v_created_by,
		v_order_number,
		v_product_name
	from public.maintenance_orders mo
	where
		mo.id = p_order_id
	for update;

	if v_wf in ('completed', 'cancelled') then
		raise exception 'invalid workflow_status';
	end if;

	if v_rol = 'PANOL' then
		if v_wf not in (
			'forwarded_to_panol',
			'panol_requested_compras',
			'compras_oc_notified',
			'compras_purchase_done',
			'compras_arrived_notified',
			'supervisor_stock_ok'
		) then
			raise exception 'forbidden for panol status';
		end if;
	end if;

	if v_stock_id is not null and v_deducted_at is not null then
		update public.stock_items si
		set cantidad = si.cantidad + v_qty
		where si.id = v_stock_id;

		get diagnostics v_st = row_count;

		if v_st <> 1 then
			raise exception 'stock restore failed';
		end if;
	end if;

	update public.maintenance_orders mo
	set
		workflow_status = 'cancelled',
		cancellation_observacion = v_obs,
		cancelled_by = v_uid,
		cancelled_at = timezone ('utc', now ()),
		updated_at = timezone ('utc', now ())
	where
		mo.id = p_order_id
		and mo.workflow_status = v_wf;

	get diagnostics v_mo = row_count;

	if v_mo <> 1 then
		raise exception 'maintenance_orders concurrent update';
	end if;

	if v_created_by is not null then
		insert into public.maintenance_order_notifications (
			user_id,
			order_id,
			kind,
			title,
			body
		)
		values (
			v_created_by,
			p_order_id,
			'pedido_anulado',
			'Pedido anulado',
			concat_ws (
				' · ',
				coalesce (v_order_number, ''),
				coalesce (v_product_name, ''),
				'Motivo: ' || v_obs
			)
		);
	end if;
end;
$$;

comment on function public.cancel_maintenance_order (uuid, text) is
	'Supervisor/admin/pañol anula un pedido activo; restaura stock si ya se descontó y avisa al técnico.';

grant execute on function public.cancel_maintenance_order (uuid, text) to authenticated;
