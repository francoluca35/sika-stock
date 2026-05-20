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
	'Retiro: descuenta una vez; p_stock_item_id opcional para cambiar lÃ­nea antes de cerrar.';

grant execute on function public.complete_maintenance_order_with_inventory (uuid, uuid) to authenticated;
-- Restaura paso "compra realizada" (RLS + check) tras 20260518120000 que lo omitiÃ³.

alter table public.maintenance_orders
	drop constraint if exists maintenance_orders_workflow_status_check;

alter table public.maintenance_orders
	add constraint maintenance_orders_workflow_status_check
		check (
			workflow_status in (
				'pending_supervisor',
				'supervisor_stock_ok',
				'forwarded_to_panol',
				'panol_requested_compras',
				'compras_oc_notified',
				'compras_purchase_done',
				'compras_arrived_notified',
				'completed',
				'cancelled'
			)
		);

drop policy if exists "maintenance_orders_select" on public.maintenance_orders;

create policy "maintenance_orders_select"
	on public.maintenance_orders
	for select
	to authenticated
	using (
		created_by = auth.uid ()
		or exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		)
		or (
			workflow_status in (
				'forwarded_to_panol',
				'panol_requested_compras',
				'compras_oc_notified',
				'compras_purchase_done',
				'compras_arrived_notified',
				'supervisor_stock_ok',
				'completed',
				'cancelled'
			)
			and exists (
				select 1
				from public.profiles p
				where
					p.id = auth.uid ()
					and p.rol = 'PANOL'
			)
		)
		or (
			exists (
				select 1
				from public.profiles p
				where
					p.id = auth.uid ()
					and p.rol = 'COMPRAS'
			)
			and workflow_status in (
				'panol_requested_compras',
				'compras_oc_notified',
				'compras_purchase_done',
				'compras_arrived_notified'
			)
		)
	);

drop policy if exists "maintenance_orders_compras_purchase_done" on public.maintenance_orders;

create policy "maintenance_orders_compras_purchase_done"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol = 'COMPRAS'
		)
		and exists (
			select 1
			from public.compras_panol_stock_requests r
			where
				r.maintenance_order_id = maintenance_orders.id
		)
		and workflow_status = 'compras_oc_notified'
	)
	with check (workflow_status = 'compras_purchase_done');

drop policy if exists "maintenance_orders_compras_llegada" on public.maintenance_orders;

create policy "maintenance_orders_compras_llegada"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol = 'COMPRAS'
		)
		and exists (
			select 1
			from public.compras_panol_stock_requests r
			where
				r.maintenance_order_id = maintenance_orders.id
		)
		and workflow_status = 'compras_purchase_done'
	)
	with check (workflow_status = 'compras_arrived_notified');

comment on policy "maintenance_orders_compras_purchase_done" on public.maintenance_orders is
	'Compras: OC emitida â†’ compra realizada.';

comment on policy "maintenance_orders_compras_llegada" on public.maintenance_orders is
	'Compras: compra realizada â†’ material en planta.';
-- Avisos alineados a flujo operativo (producciÃ³n).
-- Supervisor sin stock â†’ paÃ±ol + mantenimiento.
-- OC / compra realizada â†’ solo paÃ±ol + supervisor.
-- En planta â†’ solo supervisor + mantenimiento (sin paÃ±ol).

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
				'sin_stock_pendiente'
			)
		);

create or replace function public.trg_mo_after_update_supervisor_decide_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_body text;
begin
	if tg_op <> 'UPDATE' then
		return new;
	end if;

	if old.workflow_status is not distinct from new.workflow_status then
		return new;
	end if;

	v_body := concat_ws (
		' Â· ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		new.quantity::text || ' u.'
	);

	if old.workflow_status = 'pending_supervisor'
	and new.workflow_status = 'supervisor_stock_ok' then
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
			u.kind,
			u.title,
			u.body
		from (
			select
				new.created_by as uid,
				'stock_ok_retiro'::text as kind,
				'PodÃ©s retirar el pedido'::text as title,
				concat (v_body, ' Â· Stock disponible; pasÃ¡ a retirar.') as body
			union all
			select
				p.id,
				'panol_atento_retiro',
				'Retiro programado',
				concat (v_body, ' Â· Mantenimiento retirarÃ¡ material; preparÃ¡ la entrega.')
			from public.profiles p
			where
				p.rol = 'PANOL'
		) u
		where
			u.uid is not null;

		return new;
	end if;

	if old.workflow_status = 'pending_supervisor'
	and new.workflow_status = 'forwarded_to_panol' then
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
			u.kind,
			u.title,
			u.body
		from (
			select
				p.id as uid,
				'derivado_panol_panol'::text as kind,
				'Pedido derivado a paÃ±ol'::text as title,
				concat (
					v_body,
					' Â· Supervisor derivÃ³ por falta de stock; verificÃ¡ inventario o gestionÃ¡ compras.'
				) as body
			from public.profiles p
			where
				p.rol = 'PANOL'
			union all
			select
				new.created_by,
				'sin_stock_pendiente',
				'Sin stock por ahora',
				concat (v_body, ' Â· AÃºn no hay stock disponible; paÃ±ol estÃ¡ gestionando el pedido.')
			where
				new.created_by is not null
		) u
		where
			u.uid is not null;
	end if;

	return new;
end;
$$;

create or replace function public.trg_mo_after_update_compras_broadcast_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_body_oc text;
	v_body_compra text;
	v_body_planta text;
begin
	if tg_op <> 'UPDATE' then
		return new;
	end if;

	if old.workflow_status is not distinct from new.workflow_status then
		return new;
	end if;

	v_body_oc := concat_ws (
		' Â· ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Compras registrÃ³ emisiÃ³n de OC.'
	);

	v_body_compra := concat_ws (
		' Â· ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Compras confirmÃ³ que la compra fue realizada.'
	);

	v_body_planta := concat_ws (
		' Â· ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Material disponible en planta; podÃ©s retirar en paÃ±ol.'
	);

	if new.workflow_status = 'compras_oc_notified'
	and old.workflow_status = 'panol_requested_compras' then
		insert into public.maintenance_order_notifications (
			user_id,
			order_id,
			kind,
			title,
			body
		)
		select distinct
			p.id,
			new.id,
			'oc_emitida_compras',
			'Orden de compra emitida',
			v_body_oc
		from public.profiles p
		where
			p.rol in ('SUPERVISOR', 'PANOL');

		return new;
	end if;

	if new.workflow_status = 'compras_purchase_done'
	and old.workflow_status = 'compras_oc_notified' then
		insert into public.maintenance_order_notifications (
			user_id,
			order_id,
			kind,
			title,
			body
		)
		select distinct
			p.id,
			new.id,
			'compra_realizada',
			'Compra realizada',
			v_body_compra
		from public.profiles p
		where
			p.rol in ('SUPERVISOR', 'PANOL');

		return new;
	end if;

	if new.workflow_status = 'compras_arrived_notified'
	and old.workflow_status = 'compras_purchase_done' then
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
			'material_llego_planta',
			'Material en planta',
			v_body_planta
		from (
			select new.created_by as uid
			where
				new.created_by is not null
			union
			select p.id
			from public.profiles p
			where
				p.rol = 'SUPERVISOR'
		) u
		where
			u.uid is not null;

		return new;
	end if;

	return new;
end;
$$;

comment on function public.trg_mo_after_update_supervisor_decide_notify () is
	'Stock OK: mantenimiento + paÃ±ol. Sin stock: paÃ±ol + mantenimiento (pendiente).';

comment on function public.trg_mo_after_update_compras_broadcast_notify () is
	'OC/compra: paÃ±ol + supervisor. En planta: supervisor + solicitante mantenimiento.';
