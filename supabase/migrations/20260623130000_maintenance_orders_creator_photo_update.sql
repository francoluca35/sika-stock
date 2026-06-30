-- El creador debe poder guardar imagen_url tras subir la foto a Storage.

drop policy if exists "maintenance_orders_creator_update_pending" on public.maintenance_orders;

create policy "maintenance_orders_creator_update_pending"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		created_by = auth.uid ()
		and workflow_status = 'pending_supervisor'
	)
	with check (
		created_by = auth.uid ()
		and workflow_status = 'pending_supervisor'
	);

-- Lectura de fotos de pedidos (supervisor, pañol, compras, etc.).
-- INSERT/UPDATE/DELETE: ver migración 20260623140000_maintenance_order_photos_storage_rls_fix.sql

