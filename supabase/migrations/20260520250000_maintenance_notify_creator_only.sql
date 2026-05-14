-- Mantenimiento: solo avisos de compra realizada y retiro en planta al solicitante del pedido.
-- Sin fan-out a todo el rol MANTENIMIENTO ni avisos de creación / derivación / envío a compras.

-- -----------------------------------------------------------------------------
-- 1) Pañol → Compras: no avisar al creador del pedido
-- -----------------------------------------------------------------------------
create or replace function public.trg_cpsr_after_insert_notify_roles ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_body text;
begin
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
		p.id,
		new.maintenance_order_id,
		'enviado_a_compras',
		'Pedido enviado a compras',
		v_body
	from public.profiles p
	where
		p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN');

	return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2) Supervisor decide: derivado a pañol sin aviso al solicitante
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
			p.id,
			new.id,
			'derivado_panol_panol',
			'Pedido derivado a pañol',
			concat (
				v_body,
				' · Supervisor derivó por falta de stock; verificá inventario o gestioná compras.'
			)
		from public.profiles p
		where
			p.rol = 'PANOL';
	end if;

	return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3) Compras: OC a roles operativos; compra/llegada solo al solicitante (MANTENIMIENTO)
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
		'Compras registró emisión de OC.'
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
		select
			new.created_by,
			new.id,
			'compra_realizada',
			'Compra realizada',
			v_body_compra
		where
			new.created_by is not null;

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
				p.rol in (
					'SUPERVISOR',
					'PANOL',
					'COMPRAS',
					'ADMIN',
					'SUPERADMIN'
				)
		) u
		where
			u.uid is not null;

		return new;
	end if;

	return new;
end;
$$;

comment on function public.trg_mo_after_update_compras_broadcast_notify () is
	'OC a roles operativos; compra realizada y llegada a planta al solicitante del pedido.';

-- -----------------------------------------------------------------------------
-- 4) Pañol llegada: requiere compra realizada (alineado con la app)
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
