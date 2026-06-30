-- Corrige RLS de Storage para fotos de pedidos (error 403 al subir).

drop policy if exists "mo_photos_insert_own" on storage.objects;
drop policy if exists "mo_photos_update_own" on storage.objects;
drop policy if exists "mo_photos_delete_own" on storage.objects;
drop policy if exists "mo_photos_select_authenticated" on storage.objects;

-- Subir solo a carpeta propia: {auth.uid()}/{pedido}.jpg
create policy "mo_photos_insert_own"
	on storage.objects
	for insert
	to authenticated
	with check (
		bucket_id = 'maintenance-order-photos'
		and name like (auth.uid ()::text || '/%')
	);

-- Reemplazar foto (upsert) en carpeta propia.
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

create policy "mo_photos_delete_own"
	on storage.objects
	for delete
	to authenticated
	using (
		bucket_id = 'maintenance-order-photos'
		and name like (auth.uid ()::text || '/%')
	);

-- Ver/descargar fotos de cualquier pedido (supervisor, pañol, etc.).
create policy "mo_photos_select_authenticated"
	on storage.objects
	for select
	to authenticated
	using (bucket_id = 'maintenance-order-photos');
