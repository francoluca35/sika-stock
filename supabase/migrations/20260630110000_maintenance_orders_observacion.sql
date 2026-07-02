-- Comentario libre del técnico de mantenimiento al crear el pedido.

alter table public.maintenance_orders
	add column if not exists observacion text not null default '';

comment on column public.maintenance_orders.observacion is
	'Observación del solicitante: contexto, uso, detalles del material pedido.';
