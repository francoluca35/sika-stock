-- Campos de plantilla (PDF) + formulario de cierre + fechas de OT.

alter table public.work_orders
	add column if not exists pdf_metadata jsonb not null default '{}'::jsonb;

alter table public.work_order_responses
	add column if not exists form_data jsonb not null default '{}'::jsonb,
	add column if not exists started_at timestamptz,
	add column if not exists finished_at timestamptz,
	add column if not exists attachment_paths text[] not null default '{}';

comment on column public.work_orders.pdf_metadata is 'Datos extraídos del PDF oficial (solo lectura en app).';
comment on column public.work_order_responses.form_data is 'Novedades/tareas y campos editables del técnico.';
comment on column public.work_order_responses.started_at is 'Fecha inicio OT (día de cierre).';
comment on column public.work_order_responses.finished_at is 'Fecha finalización OT (día de cierre).';
