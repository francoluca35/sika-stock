-- Pañol y Supervisor pueden listar solicitudes a compras para la pantalla de seguimiento.

drop policy if exists "cpsr_select_panol_supervisor" on public.compras_panol_stock_requests;

create policy "cpsr_select_panol_supervisor"
	on public.compras_panol_stock_requests for select to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('PANOL', 'SUPERVISOR', 'ADMIN', 'SUPERADMIN')
		)
	);
