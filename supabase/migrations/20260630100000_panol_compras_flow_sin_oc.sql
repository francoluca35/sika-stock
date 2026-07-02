-- Pañol gestiona el flujo de compras sin pasos de OC en la app.
-- 1) Pedido a compras (insert en compras_panol_stock_requests → panol_requested_compras)
-- 2) Listo para retirar (pañol → compras_arrived_notified)

create or replace function public.trg_mo_after_update_compras_broadcast_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_body_planta text;
begin
	if tg_op <> 'UPDATE' then
		return new;
	end if;

	if old.workflow_status is not distinct from new.workflow_status then
		return new;
	end if;

	v_body_planta := concat_ws (
		' · ',
		coalesce (new.order_number, ''),
		coalesce (new.product_name, ''),
		'Pañol avisó que el material está listo para retirar.'
	);

	if new.workflow_status = 'compras_arrived_notified'
	and old.workflow_status in (
		'panol_requested_compras',
		'compras_oc_notified',
		'compras_purchase_done'
	) then
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
			'Listo para retirar',
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

comment on function public.trg_mo_after_update_compras_broadcast_notify () is
	'Listo para retirar: pañol avisa a supervisor y solicitante mantenimiento.';

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
		and workflow_status in (
			'panol_requested_compras',
			'compras_oc_notified',
			'compras_purchase_done'
		)
	)
	with check (workflow_status = 'compras_arrived_notified');

comment on policy "maintenance_orders_panol_llegada" on public.maintenance_orders is
	'Pañol avisa listo para retirar tras pedido a compras (sin pasos OC en app).';
