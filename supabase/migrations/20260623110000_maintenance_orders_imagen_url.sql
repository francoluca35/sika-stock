-- Foto adjunta al crear pedido de mantenimiento (Storage + columna en maintenance_orders).

alter table public.maintenance_orders
	add column if not exists imagen_url text;

comment on column public.maintenance_orders.imagen_url is
	'URL pública de la foto que adjuntó mantenimiento al crear el pedido.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
	'maintenance-order-photos',
	'maintenance-order-photos',
	true,
	307200,
	array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
	public = excluded.public,
	file_size_limit = excluded.file_size_limit,
	allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "mo_photos_insert_own" on storage.objects;

create policy "mo_photos_insert_own"
	on storage.objects
	for insert
	to authenticated
	with check (
		bucket_id = 'maintenance-order-photos'
		and name like (auth.uid ()::text || '/%')
	);

drop policy if exists "mo_photos_update_own" on storage.objects;

create policy "mo_photos_update_own"
	on storage.objects
	for update
	to authenticated
	using (
		bucket_id = 'maintenance-order-photos'
		and name like (auth.uid ()::text || '/%')
	)
	with check (
		bucket_id = 'maintenance-order-photos'
		and name like (auth.uid ()::text || '/%')
	);

drop policy if exists "mo_photos_delete_own" on storage.objects;

create policy "mo_photos_delete_own"
	on storage.objects
	for delete
	to authenticated
	using (
		bucket_id = 'maintenance-order-photos'
		and name like (auth.uid ()::text || '/%')
	);

drop policy if exists "mo_photos_select_authenticated" on storage.objects;

create policy "mo_photos_select_authenticated"
	on storage.objects
	for select
	to authenticated
	using (bucket_id = 'maintenance-order-photos');
