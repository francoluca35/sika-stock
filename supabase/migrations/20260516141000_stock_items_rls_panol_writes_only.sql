-- Solo **PAÑOL** puede insertar/actualizar/borrar ítems de inventario.
-- Supervisor, admin y demás roles con SELECT siguen en solo lectura.

comment on table public.stock_items is 'Inventario; lectura para roles operativos; alta/edición/baja solo PAÑOL.';

drop policy if exists "stock_items_insert_operators" on public.stock_items;
drop policy if exists "stock_items_update_operators" on public.stock_items;
drop policy if exists "stock_items_delete_operators" on public.stock_items;

create policy "stock_items_insert_panol"
	on public.stock_items for insert to authenticated
	with check (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	);

create policy "stock_items_update_panol"
	on public.stock_items for update to authenticated
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

create policy "stock_items_delete_panol"
	on public.stock_items for delete to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where p.id = auth.uid ()
				and p.rol = 'PANOL'
		)
	);
