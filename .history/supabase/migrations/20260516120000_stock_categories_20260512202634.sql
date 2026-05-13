-- Categorías de stock: lectura para usuarios autenticados; alta/edición/baja solo rol PAÑOL.

create table if not exists public.stock_categories (
	id uuid primary key default gen_random_uuid (),
	name text not null,
	created_at timestamptz not null default now (),
	updated_at timestamptz not null default now ()
);

comment on table public.stock_categories is 'Categorías de productos; las gestiona solo PAÑOL.';

create unique index if not exists stock_categories_name_lower_idx
	on public.stock_categories (lower (trim (both from name)));

drop trigger if exists stock_categories_set_updated_at on public.stock_categories;
create trigger stock_categories_set_updated_at
	before update on public.stock_categories
	for each row
	execute procedure public.set_updated_at ();

alter table public.stock_categories enable row level security;

grant select, insert, update, delete on table public.stock_categories to authenticated;

drop policy if exists "stock_categories_select_authenticated" on public.stock_categories;
create policy "stock_categories_select_authenticated"
	on public.stock_categories for select to authenticated
	using (true);

drop policy if exists "stock_categories_insert_panol" on public.stock_categories;
create policy "stock_categories_insert_panol"
	on public.stock_categories for insert to authenticated
	with check (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	);

drop policy if exists "stock_categories_update_panol" on public.stock_categories;
create policy "stock_categories_update_panol"
	on public.stock_categories for update to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	)
	with check (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	);

drop policy if exists "stock_categories_delete_panol" on public.stock_categories;
create policy "stock_categories_delete_panol"
	on public.stock_categories for delete to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	);

-- Datos iniciales (misma base que kDefaultStockCategories en la app).
insert into public.stock_categories (name)
select v
from unnest(
	array[
		'Materiales',
		'Herramientas',
		'Repuestos',
		'Consumibles',
		'Otro'
	]
) as t (v)
where not exists (
	select 1
	from public.stock_categories c
	where lower(trim (both from c.name)) = lower(trim (both from t.v))
);
