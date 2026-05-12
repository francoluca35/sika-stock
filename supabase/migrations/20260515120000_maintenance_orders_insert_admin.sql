-- Permitir que ADMIN y SUPERADMIN creen pedidos de mantenimiento (mismo flujo hacia supervisor).
drop policy if exists "maintenance_orders_insert_mantenimiento" on public.maintenance_orders;

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
				and p.rol in ('MANTENIMIENTO', 'ADMIN', 'SUPERADMIN')
		)
	);

comment on table public.maintenance_orders is 'Pedidos: MANTENIMIENTO, ADMIN o SUPERADMIN crean; SUPERVISOR define stock o deriva a PAÑOL.';
