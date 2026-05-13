-- Borra todos los pedidos de mantenimiento y filas relacionadas (notificaciones,
-- solicitudes pañol→compras, avisos in-app de compras).
--
-- Ejecutar en Supabase → SQL Editor (rol con permisos sobre public), o:
--   npx supabase db query --linked --file supabase/scripts/wipe_pedidos.sql
--   npx supabase db query --local --file supabase/scripts/wipe_pedidos.sql
--
-- No toca perfiles, stock_items ni categorías.

begin;

truncate table public.maintenance_orders restart identity cascade;

commit;
