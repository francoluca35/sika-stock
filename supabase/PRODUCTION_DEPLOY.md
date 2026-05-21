# Despliegue a producción (Supabase)

Ejecutá **una sola vez** en el proyecto de producción:

**Dashboard → SQL Editor → New query → pegar y Run:**

Archivo: [`PRODUCTION_APPLY.sql`](./PRODUCTION_APPLY.sql)

**Órdenes de trabajo (nuevo):** ejecutá también  
[`migrations/20260520400000_work_orders_module.sql`](./migrations/20260520400000_work_orders_module.sql)  
(crea tablas, bucket `work-orders` y políticas).

Incluye en `PRODUCTION_APPLY.sql` (si aún no lo actualizaste, corré las migraciones 203200–203400 por separado):

1. Fix retiro pañol (RPC `complete_maintenance_order_with_inventory`, sin overload PGRST203)
2. Fix Compras «Compra realizada» (RLS + estado `compras_purchase_done`)
3. Avisos según flujo operativo (supervisor / compras / en planta)

## Después del SQL

1. **Hot restart** de la app Flutter (no solo hot reload).
2. Probar con un usuario de cada rol:
   - Supervisor: Retiro OK y derivar sin stock
   - Pañol: stock encontrado / enviar a compras / retirar
   - Compras: OC emitida → Compra realizada → En planta
   - Mantenimiento: notificaciones según tabla abajo

## Matriz de avisos (post-migración)

| Evento | Quién recibe |
|--------|----------------|
| Supervisor hay stock | Mantenimiento + Pañol |
| Supervisor sin stock | Pañol + Mantenimiento |
| Pañol encontró stock | Supervisor + Mantenimiento |
| Compras OC / Compra realizada | Solo Pañol + Supervisor |
| Material en planta | Solo Supervisor + Mantenimiento |

Compras sigue recibiendo solicitudes en `compras_in_app_notifications` cuando Pañol deriva a compras.
