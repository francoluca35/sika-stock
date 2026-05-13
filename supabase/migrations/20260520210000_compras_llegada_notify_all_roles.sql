-- Llegada a planta / OC emitida: notificar a todos los roles operativos.

create or replace function public.trg_mo_after_update_compras_broadcast_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_body_oc text;
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

	v_body_planta := concat_ws (
		' · ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Compras confirmó llegada del material a planta.'
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

comment on function public.trg_mo_after_update_compras_broadcast_notify () is
	'OC emitida / material en planta: fan-out a todos los roles en maintenance_order_notifications.';
