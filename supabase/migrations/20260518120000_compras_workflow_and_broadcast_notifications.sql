-- Flujo Pañol → Compras: estados en maintenance_orders, avisos broadcast y llegada a planta.

-- -----------------------------------------------------------------------------
-- 1) Nuevos valores de workflow en maintenance_orders
-- -----------------------------------------------------------------------------
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
				'compras_arrived_notified',
				'completed',
				'cancelled'
			)
		);

-- -----------------------------------------------------------------------------
-- 2) Nuevos kinds en maintenance_order_notifications
-- -----------------------------------------------------------------------------
alter table public.maintenance_order_notifications
	drop constraint if exists maintenance_order_notifications_kind_check;

alter table public.maintenance_order_notifications
	add constraint maintenance_order_notifications_kind_check
		check (
			kind in (
				'stock_ok_retiro',
				'derivado_panol',
				'oc_emitida_compras',
				'material_llego_planta'
			)
		);

-- -----------------------------------------------------------------------------
-- 3) Tras insertar solicitud Pañol→Compras: avanzar workflow del pedido
-- -----------------------------------------------------------------------------
create or replace function public.trg_cpsr_after_insert_set_mo_workflow ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
begin
	update public.maintenance_orders
	set
		workflow_status = 'panol_requested_compras',
		updated_at = now ()
	where
		id = new.maintenance_order_id
		and workflow_status = 'forwarded_to_panol';

	return new;
end;
$$;

drop trigger if exists cpsr_after_insert_set_mo_workflow on public.compras_panol_stock_requests;

create trigger cpsr_after_insert_set_mo_workflow
	after insert on public.compras_panol_stock_requests
	for each row
	execute procedure public.trg_cpsr_after_insert_set_mo_workflow ();

-- -----------------------------------------------------------------------------
-- 4) Al pasar a OC emitida / material en planta: notificaciones (fan-out)
-- -----------------------------------------------------------------------------
create or replace function public.trg_mo_after_update_compras_broadcast_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
begin
	if tg_op <> 'UPDATE' then
		return new;
	end if;

	if old.workflow_status is not distinct from new.workflow_status then
		return new;
	end if;

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
			u.uid,
			new.id,
			'oc_emitida_compras',
			'Orden de compra emitida',
			concat_ws (
				' · ',
				coalesce (new.order_number, ''),
				coalesce (new.product_name, ''),
				'Compras registró emisión de OC.'
			)
		from (
			select p.id as uid
			from public.profiles p
			where
				p.rol in ('PANOL', 'SUPERVISOR', 'ADMIN', 'SUPERADMIN')
			union
			select mo.created_by
			from public.maintenance_orders mo
			where
				mo.id = new.id
		) u
		where
			u.uid is not null;

		return new;
	end if;

	if new.workflow_status = 'compras_arrived_notified'
	and old.workflow_status = 'compras_oc_notified' then
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
			concat_ws (
				' · ',
				coalesce (new.order_number, ''),
				coalesce (new.product_name, ''),
				'Compras confirmó llegada del material a planta.'
			)
		from (
			select p.id as uid
			from public.profiles p
			where
				p.rol in ('PANOL', 'SUPERVISOR', 'ADMIN', 'SUPERADMIN')
			union
			select mo.created_by
			from public.maintenance_orders mo
			where
				mo.id = new.id
		) u
		where
			u.uid is not null;

		return new;
	end if;

	return new;
end;
$$;

drop trigger if exists mo_after_update_compras_broadcast_notify on public.maintenance_orders;

create trigger mo_after_update_compras_broadcast_notify
	after update on public.maintenance_orders
	for each row
	execute procedure public.trg_mo_after_update_compras_broadcast_notify ();

-- -----------------------------------------------------------------------------
-- 5) RLS: lectura de pedidos para COMPRAS (con solicitud registrada)
-- -----------------------------------------------------------------------------
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
				'compras_arrived_notified'
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
				'compras_arrived_notified'
			)
		)
	);

-- -----------------------------------------------------------------------------
-- 6) RLS: COMPRAS actualiza OC emitida / llegada a planta
-- -----------------------------------------------------------------------------
drop policy if exists "maintenance_orders_compras_oc" on public.maintenance_orders;

create policy "maintenance_orders_compras_oc"
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
		and workflow_status = 'panol_requested_compras'
	)
	with check (workflow_status = 'compras_oc_notified');

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
		and workflow_status = 'compras_oc_notified'
	)
	with check (workflow_status = 'compras_arrived_notified');

-- -----------------------------------------------------------------------------
-- 7) Supervisor puede cerrar también desde “material en planta”
-- -----------------------------------------------------------------------------
drop policy if exists "maintenance_orders_supervisor_complete" on public.maintenance_orders;

create policy "maintenance_orders_supervisor_complete"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		workflow_status in ('supervisor_stock_ok', 'compras_arrived_notified')
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		)
	)
	with check (workflow_status = 'completed');
