-- El usuario puede descartar sus propios avisos (cruz en home).

drop policy if exists "mon_delete_own" on public.maintenance_order_notifications;

create policy "mon_delete_own"
	on public.maintenance_order_notifications
	for delete
	to authenticated
	using (user_id = auth.uid ());
