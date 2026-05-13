-- Ítems de inventario (stock). Sin datos iniciales: la carga es manual / por la app.

create table if not exists public.stock_items (
	id uuid primary key default gen_random_uuid (),
	nombre text not null,
	categoria text not null,
	cantidad int not null default 0 check (cantidad >= 0),
	codigo text,
	created_at timestamptz not null default now (),
	updated_at timestamptz not null default now ()
);

comment on table public.stock_items is 'Inventario; lectura roles operativos; alta/edición/baja solo PAÑOL (ver migración 20260516141000).';

create index if not exists stock_items_nombre_idx on public.stock_items (lower (nombre));
create index if not exists stock_items_categoria_idx on public.stock_items (lower (categoria));

drop trigger if exists stock_items_set_updated_at on public.stock_items;
create trigger stock_items_set_updated_at
	before update on public.stock_items
	for each row
	execute procedure public.set_updated_at ();

alter table public.stock_items enable row level security;

grant select, insert, update, delete on table public.stock_items to authenticated;

drop policy if exists "stock_items_select_authenticated" on public.stock_items;
create policy "stock_items_select_authenticated"
	on public.stock_items for select to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol in (
					'MANTENIMIENTO',
					'SUPERVISOR',
					'PANOL',
					'COMPRAS',
					'ADMIN',
					'SUPERADMIN'
				)
		)
	);

drop policy if exists "stock_items_insert_operators" on public.stock_items;
create policy "stock_items_insert_operators"
	on public.stock_items for insert to authenticated
	with check (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol in ('PANOL', 'ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "stock_items_update_operators" on public.stock_items;
create policy "stock_items_update_operators"
	on public.stock_items for update to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol in ('PANOL', 'ADMIN', 'SUPERADMIN')
		)
	)
	with check (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol in ('PANOL', 'ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "stock_items_delete_operators" on public.stock_items;
create policy "stock_items_delete_operators"
	on public.stock_items for delete to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol in ('PANOL', 'ADMIN', 'SUPERADMIN')
		)
	);
