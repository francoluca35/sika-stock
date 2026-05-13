-- Evita recursión infinita: maintenance_orders_select no debe consultar
-- compras_panol_stock_requests, porque cpsr_insert ya lee maintenance_orders.

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
