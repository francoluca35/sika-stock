-- SUPERVISOR puede dar de alta una OM desde el flujo "elegir producto" (catálogo),
-- para luego confirmar stock o derivar a pañol en el mismo circuito que mantenimiento.

drop policy if exists "maintenance_orders_insert_solicitantes" on public.maintenance_orders;

create policy "maintenance_orders_insert_solicitantes"
	on public.maintenance_orders
	for insert
	to authenticated
	with check (
		created_by = auth.uid ()
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('MANTENIMIENTO', 'ADMIN', 'SUPERADMIN', 'SUPERVISOR')
		)
	);

comment on table public.maintenance_orders is 'Pedidos: MANTENIMIENTO, ADMIN, SUPERADMIN o SUPERVISOR crean; SUPERVISOR confirma stock o deriva a PAÑOL.';
