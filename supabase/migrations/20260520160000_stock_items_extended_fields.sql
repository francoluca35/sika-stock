-- Campos adicionales en inventario: descripciones, marca.

alter table public.stock_items
	add column if not exists descripcion_empresa text not null default '',
	add column if not exists descripcion_fabricante text not null default '',
	add column if not exists marca text not null default '';

comment on column public.stock_items.descripcion_empresa is 'Descripción según la empresa.';
comment on column public.stock_items.descripcion_fabricante is 'Descripción según el fabricante.';
comment on column public.stock_items.marca is 'Marca del producto.';

create index if not exists stock_items_marca_idx on public.stock_items (lower (marca));
