-- Avisos alineados a flujo operativo (producción).
-- Supervisor sin stock → pañol + mantenimiento.
-- OC / compra realizada → solo pañol + supervisor.
-- En planta → solo supervisor + mantenimiento (sin pañol).

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
				p.id as uid,
				'derivado_panol_panol'::text as kind,
				'Pedido derivado a pañol'::text as title,
				concat (
					v_body,
					' · Supervisor derivó por falta de stock; verificá inventario o gestioná compras.'
				) as body
			from public.profiles p
			where
				p.rol = 'PANOL'
			union all
			select
				new.created_by,
				'sin_stock_pendiente',
				'Sin stock por ahora',
				concat (v_body, ' · Aún no hay stock disponible; pañol está gestionando el pedido.')
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
	'Stock OK: mantenimiento + pañol. Sin stock: pañol + mantenimiento (pendiente).';

comment on function public.trg_mo_after_update_compras_broadcast_notify () is
	'OC/compra: pañol + supervisor. En planta: supervisor + solicitante mantenimiento.';
