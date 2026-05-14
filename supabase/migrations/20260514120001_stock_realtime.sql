-- Realtime: inventario y categorías (actualización en vivo del catálogo).

do $$
begin
	alter publication supabase_realtime add table public.stock_items;
exception
	when duplicate_object then null;
end $$;

do $$
begin
	alter publication supabase_realtime add table public.stock_categories;
exception
	when duplicate_object then null;
end $$;

alter table public.maintenance_orders replica identity full;
alter table public.maintenance_order_notifications replica identity full;
alter table public.stock_items replica identity full;
