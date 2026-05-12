-- Pedidos de mantenimiento: alta en BD → supervisor decide stock → pañol si no hay stock.
-- Aplicar con `supabase db push` o SQL Editor.

-- -----------------------------------------------------------------------------
-- Tabla
-- -----------------------------------------------------------------------------
create table if not exists public.maintenance_orders (
	id uuid primary key default gen_random_uuid (),
	created_at timestamptz not null default now (),
	updated_at timestamptz not null default now (),
	created_by uuid not null references public.profiles (id) on delete restrict,
	solicitante_display text not null,
	product_name text not null,
	quantity int not null check (quantity >= 1),
	product_type text not null,
	priority text not null,
	destination text not null,
	order_number text not null unique default (
		'ORD-' || upper (substr (md5 (random ()::text || clock_timestamp ()::text), 1, 8))
	),
	workflow_status text not null default 'pending_supervisor'
		check (
			workflow_status in (
				'pending_supervisor',
				'supervisor_stock_ok',
				'forwarded_to_panol',
				'completed',
				'cancelled'
			)
		),
	supervisor_id uuid references public.profiles (id),
	supervisor_decided_at timestamptz,
	supervisor_note text
);

comment on table public.maintenance_orders is 'Pedidos potenciamiento: MANTENIMIENTO crea; SUPERVISOR confirma stock o deriva a PAÑOL.';

create index if not exists maintenance_orders_workflow_idx
	on public.maintenance_orders (workflow_status);

create index if not exists maintenance_orders_created_at_idx
	on public.maintenance_orders (created_at desc);

drop trigger if exists maintenance_orders_set_updated_at on public.maintenance_orders;

create trigger maintenance_orders_set_updated_at
	before update on public.maintenance_orders
	for each row
	execute procedure public.set_updated_at ();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.maintenance_orders enable row level security;

drop policy if exists "maintenance_orders_insert_mantenimiento" on public.maintenance_orders;

create policy "maintenance_orders_insert_mantenimiento"
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
				and p.rol = 'MANTENIMIENTO'
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
			workflow_status = 'forwarded_to_panol'
			and exists (
				select 1
				from public.profiles p
				where
					p.id = auth.uid ()
					and p.rol = 'PANOL'
			)
		)
	);

drop policy if exists "maintenance_orders_supervisor_decide" on public.maintenance_orders;

create policy "maintenance_orders_supervisor_decide"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		workflow_status = 'pending_supervisor'
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		)
	)
	with check (
		workflow_status in ('supervisor_stock_ok', 'forwarded_to_panol')
	);

drop policy if exists "maintenance_orders_supervisor_complete" on public.maintenance_orders;

create policy "maintenance_orders_supervisor_complete"
	on public.maintenance_orders
	for update
	to authenticated
	using (
		workflow_status = 'supervisor_stock_ok'
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		)
	)
	with check (workflow_status = 'completed');
