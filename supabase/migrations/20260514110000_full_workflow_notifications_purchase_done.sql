-- Flujo operativo completo: descuento al confirmar supervisor, notificaciones fan-out,
-- paso intermedio compra realizada y avisos a pañol / supervisor / mantenimiento.

-- -----------------------------------------------------------------------------
-- 1) Columna: stock ya descontado al confirmar supervisor
-- -----------------------------------------------------------------------------
alter table public.maintenance_orders
	add column if not exists stock_deducted_at timestamptz;

comment on column public.maintenance_orders.stock_deducted_at is
	'Marca de tiempo si el inventario ya fue descontado (p. ej. al confirmar stock del supervisor).';

-- -----------------------------------------------------------------------------
-- 2) Nuevo estado: compra realizada (entre OC emitida y llegada a planta)
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
				'compras_purchase_done',
				'compras_arrived_notified',
				'completed',
				'cancelled'
			)
		);

-- -----------------------------------------------------------------------------
-- 3) Kinds de notificación ampliados
-- -----------------------------------------------------------------------------
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
				'material_llego_planta'
			)
		);

-- -----------------------------------------------------------------------------
-- 4) Supervisor decide: descuenta stock de inmediato si hay stock
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
			stock_deducted_at = timezone ('utc', now ()),
			supervisor_id = v_uid,
			supervisor_decided_at = timezone ('utc', now ()),
			updated_at = timezone ('utc', now ())
		where
			mo.id = p_order_id
			and mo.workflow_status = 'pending_supervisor';
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
	end if;

	get diagnostics v_mo = row_count;

	if v_mo <> 1 then
		raise exception 'maintenance_orders concurrent update';
	end if;
end;
$$;

comment on function public.supervisor_decide_stock_with_inventory (uuid, boolean, uuid) is
	'Supervisor: pending_supervisor → supervisor_stock_ok (descuenta stock al instante) o forwarded_to_panol.';

-- -----------------------------------------------------------------------------
-- 5) Cierre / retiro: solo descuenta si aún no se descontó (p. ej. vía pañol)
-- -----------------------------------------------------------------------------
create or replace function public.complete_maintenance_order_with_inventory (
	p_order_id uuid
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

comment on function public.complete_maintenance_order_with_inventory (uuid) is
	'Retiro/entrega: descuenta inventario solo si no se descontó antes; pasa a completed.';

-- -----------------------------------------------------------------------------
-- 6) Avisos al decidir supervisor (mantenimiento + pañol)
-- -----------------------------------------------------------------------------
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
		' · ',
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
				'Podés retirar el pedido'::text as title,
				concat (v_body, ' · Stock disponible; pasá a retirar.') as body
			union all
			select
				p.id,
				'panol_atento_retiro',
				'Retiro programado',
				concat (v_body, ' · Mantenimiento retirará material; prepará la entrega.')
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
				new.created_by as uid,
				'derivado_panol'::text as kind,
				'Sin stock en depósito'::text as title,
				concat (
					v_body,
					' · No hay stock suficiente; pañol gestionará y te avisaremos cuando esté disponible.'
				) as body
			union all
			select
				p.id,
				'derivado_panol_panol',
				'Pedido derivado a pañol',
				concat (
					v_body,
					' · Supervisor derivó por falta de stock; verificá inventario o gestioná compras.'
				)
			from public.profiles p
			where
				p.rol = 'PANOL'
		) u
		where
			u.uid is not null;
	end if;

	return new;
end;
$$;

drop trigger if exists mo_after_update_supervisor_decide_notify on public.maintenance_orders;

create trigger mo_after_update_supervisor_decide_notify
	after update on public.maintenance_orders
	for each row
	execute procedure public.trg_mo_after_update_supervisor_decide_notify ();

-- -----------------------------------------------------------------------------
-- 7) Pañol → Compras: avisar supervisor y mantenimiento
-- -----------------------------------------------------------------------------
create or replace function public.trg_cpsr_after_insert_notify_roles ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_body text;
	v_creator uuid;
begin
	select mo.created_by
	into v_creator
	from public.maintenance_orders mo
	where
		mo.id = new.maintenance_order_id;

	v_body := concat_ws (
		' · ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		new.quantity::text || ' u.',
		'Se envió solicitud a compras por falta de stock en planta.'
	);

	insert into public.maintenance_order_notifications (
		user_id,
		order_id,
		kind,
		title,
		body
	)
	select distinct
		u.uid,
		new.maintenance_order_id,
		'enviado_a_compras',
		'Pedido enviado a compras',
		v_body
	from (
		select p.id as uid
		from public.profiles p
		where
			p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		union
		select v_creator
		where
			v_creator is not null
	) u
	where
		u.uid is not null;

	return new;
end;
$$;

drop trigger if exists cpsr_after_insert_notify_roles on public.compras_panol_stock_requests;

create trigger cpsr_after_insert_notify_roles
	after insert on public.compras_panol_stock_requests
	for each row
	execute procedure public.trg_cpsr_after_insert_notify_roles ();

-- -----------------------------------------------------------------------------
-- 8) Compras: OC emitida → compra realizada → llegada a planta (fan-out)
-- -----------------------------------------------------------------------------
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
		' · ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Compras registró emisión de orden de pre-aprobación / OC.'
	);

	v_body_compra := concat_ws (
		' · ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Compras confirmó que la compra fue realizada.'
	);

	v_body_planta := concat_ws (
		' · ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Material disponible en planta; podés retirar en pañol.'
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
			p.rol in (
				'MANTENIMIENTO',
				'SUPERVISOR',
				'PANOL',
				'COMPRAS',
				'ADMIN',
				'SUPERADMIN'
			);

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
			p.rol in (
				'MANTENIMIENTO',
				'SUPERVISOR',
				'PANOL',
				'COMPRAS',
				'ADMIN',
				'SUPERADMIN'
			);

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
			p.id,
			new.id,
			'material_llego_planta',
			'Material en planta',
			v_body_planta
		from public.profiles p
		where
			p.rol in (
				'MANTENIMIENTO',
				'SUPERVISOR',
				'PANOL',
				'COMPRAS',
				'ADMIN',
				'SUPERADMIN'
			);

		return new;
	end if;

	return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 9) RLS SELECT: incluir compras_purchase_done
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

-- -----------------------------------------------------------------------------
-- 10) RLS UPDATE Compras: OC → compra realizada → en planta
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

-- -----------------------------------------------------------------------------
-- 11) Pañol: avisar llegada desde compra realizada
-- -----------------------------------------------------------------------------
drop policy if exists "maintenance_orders_panol_llegada" on public.maintenance_orders;

create policy "maintenance_orders_panol_llegada"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('PANOL', 'ADMIN', 'SUPERADMIN')
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

comment on policy "maintenance_orders_panol_llegada" on public.maintenance_orders is
	'Pañol (u admin) avisa llegada a planta tras compra realizada.';
