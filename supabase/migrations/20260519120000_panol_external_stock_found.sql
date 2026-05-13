-- Pañol: marcar que encontró material fuera del catálogo digital → listo para retiro (supervisor_stock_ok).
-- Notificación a solicitante y roles de gestión.

alter table public.maintenance_order_notifications
	drop constraint if exists maintenance_order_notifications_kind_check;

alter table public.maintenance_order_notifications
	add constraint maintenance_order_notifications_kind_check
		check (
			kind in (
				'stock_ok_retiro',
				'derivado_panol',
				'oc_emitida_compras',
				'material_llego_planta',
				'panol_stock_externo'
			)
		);

drop policy if exists "maintenance_orders_panol_external_stock" on public.maintenance_orders;

create policy "maintenance_orders_panol_external_stock"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		workflow_status = 'forwarded_to_panol'
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	)
	with check (workflow_status = 'supervisor_stock_ok');

create or replace function public.trg_mo_after_update_panol_stock_externo_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
begin
	if tg_op <> 'UPDATE' then
		return new;
	end if;

	if old.workflow_status = 'forwarded_to_panol'
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
			'panol_stock_externo',
			'Pañol: material disponible',
			concat_ws (
				' · ',
				coalesce (new.order_number, ''),
				coalesce (new.product_name, ''),
				'Pañol confirmó stock fuera del inventario del sistema; coordinar retiro.'
			)
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

drop trigger if exists mo_after_update_panol_stock_externo on public.maintenance_orders;

create trigger mo_after_update_panol_stock_externo
	after update on public.maintenance_orders
	for each row
	execute procedure public.trg_mo_after_update_panol_stock_externo_notify ();
