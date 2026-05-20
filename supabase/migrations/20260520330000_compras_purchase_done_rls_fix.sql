-- Restaura paso "compra realizada" (RLS + check) tras 20260518120000 que lo omitió.

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

comment on policy "maintenance_orders_compras_purchase_done" on public.maintenance_orders is
	'Compras: OC emitida → compra realizada.';

comment on policy "maintenance_orders_compras_llegada" on public.maintenance_orders is
	'Compras: compra realizada → material en planta.';
