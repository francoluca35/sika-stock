-- Compras: descartar avisos propios (cruz / borrar todas).

grant delete on table public.compras_in_app_notifications to authenticated;

drop policy if exists "cin_delete_own" on public.compras_in_app_notifications;

create policy "cin_delete_own"
	on public.compras_in_app_notifications
	for delete
	to authenticated
	using (user_id = auth.uid ());
