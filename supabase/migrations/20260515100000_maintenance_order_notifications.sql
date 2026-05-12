-- Notificaciones in-app para el creador del pedido (mantenimiento) al decidir stock / pañol.
create table if not exists public.maintenance_order_notifications (
	id uuid primary key default gen_random_uuid (),
	created_at timestamptz not null default now (),
	user_id uuid not null references public.profiles (id) on delete cascade,
	order_id uuid not null references public.maintenance_orders (id) on delete cascade,
	kind text not null
		check (kind in ('stock_ok_retiro', 'derivado_panol')),
	title text not null,
	body text not null,
	read_at timestamptz
);

create index if not exists maintenance_order_notifications_user_idx
	on public.maintenance_order_notifications (user_id, created_at desc);

comment on table public.maintenance_order_notifications is 'Avisos al solicitante del pedido (p. ej. puede retirar / derivado a pañol).';

alter table public.maintenance_order_notifications enable row level security;

drop policy if exists "mon_select_own" on public.maintenance_order_notifications;

create policy "mon_select_own"
	on public.maintenance_order_notifications
	for select
	to authenticated
	using (user_id = auth.uid ());

drop policy if exists "mon_insert_supervisor" on public.maintenance_order_notifications;

create policy "mon_insert_supervisor"
	on public.maintenance_order_notifications
	for insert
	to authenticated
	with check (
		user_id = (
			select mo.created_by
			from public.maintenance_orders mo
			where
				mo.id = order_id
		)
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "mon_update_own_read" on public.maintenance_order_notifications;

create policy "mon_update_own_read"
	on public.maintenance_order_notifications
	for update
	to authenticated
	using (user_id = auth.uid ())
	with check (user_id = auth.uid ());

do $$
begin
	alter publication supabase_realtime add table public.maintenance_order_notifications;
exception
	when duplicate_object then null;
end $$;
