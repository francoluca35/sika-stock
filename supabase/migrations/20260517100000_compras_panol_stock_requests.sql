-- Solicitudes desde Pañol cuando no hay stock: notificación a rol COMPRAS + listado en historial.

create table if not exists public.compras_panol_stock_requests (
	id uuid primary key default gen_random_uuid (),
	created_at timestamptz not null default now (),
	maintenance_order_id uuid not null references public.maintenance_orders (id) on delete cascade,
	order_number text not null,
	product_name text not null,
	quantity int not null check (quantity >= 1),
	priority text not null,
	destination text not null,
	solicitante_display text not null,
	panol_user_id uuid not null references public.profiles (id) on delete restrict,
	imagen_url text,
	constraint compras_panol_stock_requests_order_unique unique (maintenance_order_id)
);

comment on table public.compras_panol_stock_requests is 'Pañol pide a Compras material sin stock; una fila por pedido de mantenimiento.';

create index if not exists compras_panol_stock_requests_created_idx
	on public.compras_panol_stock_requests (created_at desc);

alter table public.compras_panol_stock_requests enable row level security;

grant select, insert on table public.compras_panol_stock_requests to authenticated;

drop policy if exists "cpsr_select_compras_roles" on public.compras_panol_stock_requests;

create policy "cpsr_select_compras_roles"
	on public.compras_panol_stock_requests for select to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol in ('COMPRAS', 'ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "cpsr_insert_panol" on public.compras_panol_stock_requests;

create policy "cpsr_insert_panol"
	on public.compras_panol_stock_requests for insert to authenticated
	with check (
		panol_user_id = auth.uid ()
		and exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
		and exists (
			select 1
			from public.maintenance_orders mo
			where
				mo.id = maintenance_order_id
				and mo.workflow_status = 'forwarded_to_panol'
		)
	);

-- Notificaciones in-app para usuarios COMPRAS (fan-out por trigger).
create table if not exists public.compras_in_app_notifications (
	id uuid primary key default gen_random_uuid (),
	created_at timestamptz not null default now (),
	user_id uuid not null references public.profiles (id) on delete cascade,
	kind text not null
		check (kind in ('panol_stock_request')),
	ref_id uuid not null references public.compras_panol_stock_requests (id) on delete cascade,
	title text not null,
	body text not null,
	read_at timestamptz,
	constraint compras_in_app_notifications_user_ref_unique unique (user_id, ref_id)
);

comment on table public.compras_in_app_notifications is 'Avisos para Compras (p. ej. pedido desde pañol sin stock).';

create index if not exists compras_in_app_notifications_user_created_idx
	on public.compras_in_app_notifications (user_id, created_at desc);

alter table public.compras_in_app_notifications enable row level security;

grant select, update on table public.compras_in_app_notifications to authenticated;

drop policy if exists "cin_select_own" on public.compras_in_app_notifications;

create policy "cin_select_own"
	on public.compras_in_app_notifications for select to authenticated
	using (user_id = auth.uid ());

drop policy if exists "cin_update_own_read" on public.compras_in_app_notifications;

create policy "cin_update_own_read"
	on public.compras_in_app_notifications for update to authenticated
	using (user_id = auth.uid ())
	with check (user_id = auth.uid ());

create or replace function public.trg_compras_panol_stock_request_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
begin
	insert into public.compras_in_app_notifications (
		user_id,
		kind,
		ref_id,
		title,
		body
	)
	select
		p.id,
		'panol_stock_request',
		new.id,
		'Nuevo pedido desde pañol (sin stock)',
		concat_ws (
			' · ',
			new.order_number,
			new.product_name,
			new.quantity::text || ' u.',
			new.destination,
			'Prioridad: ' || new.priority
		)
	from public.profiles p
	where p.rol = 'COMPRAS';

	return new;
end;
$$;

drop trigger if exists compras_panol_stock_request_notify on public.compras_panol_stock_requests;

create trigger compras_panol_stock_request_notify
	after insert on public.compras_panol_stock_requests
	for each row
	execute procedure public.trg_compras_panol_stock_request_notify ();

do $$
begin
	alter publication supabase_realtime add table public.compras_panol_stock_requests;
exception
	when duplicate_object then null;
end $$;

do $$
begin
	alter publication supabase_realtime add table public.compras_in_app_notifications;
exception
	when duplicate_object then null;
end $$;
