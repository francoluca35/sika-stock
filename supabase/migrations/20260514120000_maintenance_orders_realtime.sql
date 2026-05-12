-- Realtime: notificar cambios en pedidos de mantenimiento (RLS sigue aplicando por sesión).
do $$
begin
	alter publication supabase_realtime add table public.maintenance_orders;
exception
	when duplicate_object then null;
end $$;
