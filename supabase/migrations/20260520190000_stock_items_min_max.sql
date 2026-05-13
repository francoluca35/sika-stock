-- Umbrales de alerta por ítem: stock bajo (por debajo del mínimo) o alto (por encima del máximo).

alter table public.stock_items
	add column if not exists cantidad_minima int not null default 0,
	add column if not exists cantidad_maxima int not null default 0;

alter table public.stock_items
	drop constraint if exists stock_items_cantidad_minima_check;

alter table public.stock_items
	add constraint stock_items_cantidad_minima_check check (cantidad_minima >= 0);

alter table public.stock_items
	drop constraint if exists stock_items_cantidad_maxima_check;

alter table public.stock_items
	add constraint stock_items_cantidad_maxima_check check (cantidad_maxima >= 0);

alter table public.stock_items
	drop constraint if exists stock_items_min_max_order_check;

alter table public.stock_items
	add constraint stock_items_min_max_order_check check (
		cantidad_maxima = 0
		or cantidad_minima <= cantidad_maxima
	);

comment on column public.stock_items.cantidad_minima is 'Alerta de stock bajo si cantidad < mínimo (0 = sin umbral mínimo).';
comment on column public.stock_items.cantidad_maxima is 'Alerta de stock alto si cantidad > máximo (0 = sin umbral máximo).';
