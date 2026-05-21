-- Órdenes de trabajo (OT): PDF original, asignación a mantenimiento, respuesta y PDF final.

-- -----------------------------------------------------------------------------
-- Storage bucket
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
	'work-orders',
	'work-orders',
	false,
	52428800,
	array['application/pdf', 'image/png', 'image/jpeg']
)
on conflict (id) do update
set
	file_size_limit = excluded.file_size_limit,
	allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- Tablas
-- -----------------------------------------------------------------------------
create table if not exists public.work_orders (
	id uuid primary key default gen_random_uuid (),
	created_at timestamptz not null default timezone ('utc', now ()),
	updated_at timestamptz not null default timezone ('utc', now ()),
	created_by uuid not null references public.profiles (id) on delete restrict,
	title text not null,
	ot_number text,
	original_pdf_path text not null,
	status text not null default 'assigned'
		check (status in ('assigned', 'completed', 'cancelled')),
	notes_admin text
);

comment on table public.work_orders is 'OT subida por admin; PDF original en Storage work-orders.';

create index if not exists work_orders_created_at_idx
	on public.work_orders (created_at desc);

create table if not exists public.work_order_assignments (
	id uuid primary key default gen_random_uuid (),
	work_order_id uuid not null references public.work_orders (id) on delete cascade,
	user_id uuid not null references public.profiles (id) on delete cascade,
	status text not null default 'pending'
		check (status in ('pending', 'completed')),
	assigned_at timestamptz not null default timezone ('utc', now ()),
	completed_at timestamptz,
	constraint work_order_assignments_unique unique (work_order_id, user_id)
);

create index if not exists work_order_assignments_user_idx
	on public.work_order_assignments (user_id, assigned_at desc);

create table if not exists public.work_order_responses (
	id uuid primary key default gen_random_uuid (),
	assignment_id uuid not null references public.work_order_assignments (id) on delete cascade,
	observations text not null default '',
	checklist jsonb not null default '[]'::jsonb,
	signature_path text,
	completed_pdf_path text,
	submitted_at timestamptz not null default timezone ('utc', now ()),
	constraint work_order_responses_assignment_unique unique (assignment_id)
);

create table if not exists public.work_order_notifications (
	id uuid primary key default gen_random_uuid (),
	user_id uuid not null references public.profiles (id) on delete cascade,
	work_order_id uuid not null references public.work_orders (id) on delete cascade,
	assignment_id uuid references public.work_order_assignments (id) on delete set null,
	title text not null,
	body text not null,
	read_at timestamptz,
	created_at timestamptz not null default timezone ('utc', now ())
);

create index if not exists work_order_notifications_user_created_idx
	on public.work_order_notifications (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- updated_at
-- -----------------------------------------------------------------------------
drop trigger if exists work_orders_set_updated_at on public.work_orders;

create trigger work_orders_set_updated_at
	before update on public.work_orders
	for each row
	execute procedure public.set_updated_at ();

-- -----------------------------------------------------------------------------
-- Notificar al asignar
-- -----------------------------------------------------------------------------
create or replace function public.trg_work_order_assignment_notify ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_title text;
	v_body text;
begin
	select wo.title, coalesce (wo.ot_number, '')
	into v_title, v_body
	from public.work_orders wo
	where wo.id = new.work_order_id;

	insert into public.work_order_notifications (
		user_id,
		work_order_id,
		assignment_id,
		title,
		body
	)
	values (
		new.user_id,
		new.work_order_id,
		new.id,
		'Nueva orden de trabajo',
		concat (
			coalesce (nullif (trim (v_body), ''), v_title),
			' · Tenés una OT para completar y firmar.'
		)
	);

	return new;
end;
$$;

drop trigger if exists work_order_assignment_notify on public.work_order_assignments;

create trigger work_order_assignment_notify
	after insert on public.work_order_assignments
	for each row
	execute procedure public.trg_work_order_assignment_notify ();

-- -----------------------------------------------------------------------------
-- Marcar OT completada cuando todos los asignados terminaron
-- -----------------------------------------------------------------------------
create or replace function public.trg_work_order_response_mark_done ()
	returns trigger
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	v_wo uuid;
	v_pending int;
begin
	select a.work_order_id
	into strict v_wo
	from public.work_order_assignments a
	where a.id = new.assignment_id;

	update public.work_order_assignments a
	set
		status = 'completed',
		completed_at = timezone ('utc', now ())
	where
		a.id = new.assignment_id;

	select count(*)::int
	into v_pending
	from public.work_order_assignments a
	where
		a.work_order_id = v_wo
		and a.status = 'pending';

	if v_pending = 0 then
		update public.work_orders wo
		set status = 'completed'
		where wo.id = v_wo;
	end if;

	return new;
end;
$$;

drop trigger if exists work_order_response_mark_done on public.work_order_responses;

create trigger work_order_response_mark_done
	after insert on public.work_order_responses
	for each row
	execute procedure public.trg_work_order_response_mark_done ();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.work_orders enable row level security;
alter table public.work_order_assignments enable row level security;
alter table public.work_order_responses enable row level security;
alter table public.work_order_notifications enable row level security;

grant select, insert, update on public.work_orders to authenticated;
grant select, insert, update on public.work_order_assignments to authenticated;
grant select, insert on public.work_order_responses to authenticated;
grant select, update, delete on public.work_order_notifications to authenticated;

drop policy if exists "work_orders_admin_all" on public.work_orders;

create policy "work_orders_admin_all"
	on public.work_orders
	for all
	to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	)
	with check (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "work_orders_mantenimiento_select" on public.work_orders;

create policy "work_orders_mantenimiento_select"
	on public.work_orders
	for select
	to authenticated
	using (
		exists (
			select 1
			from public.work_order_assignments a
			where
				a.work_order_id = work_orders.id
				and a.user_id = auth.uid ()
		)
	);

drop policy if exists "work_order_assignments_admin" on public.work_order_assignments;

create policy "work_order_assignments_admin"
	on public.work_order_assignments
	for all
	to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	)
	with check (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "work_order_assignments_own" on public.work_order_assignments;

create policy "work_order_assignments_own"
	on public.work_order_assignments
	for select
	to authenticated
	using (user_id = auth.uid ());

drop policy if exists "work_order_responses_admin_select" on public.work_order_responses;

create policy "work_order_responses_admin_select"
	on public.work_order_responses
	for select
	to authenticated
	using (
		exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "work_order_responses_insert_own" on public.work_order_responses;

create policy "work_order_responses_insert_own"
	on public.work_order_responses
	for insert
	to authenticated
	with check (
		exists (
			select 1
			from public.work_order_assignments a
			where
				a.id = assignment_id
				and a.user_id = auth.uid ()
				and a.status = 'pending'
		)
	);

drop policy if exists "won_select_own" on public.work_order_notifications;

create policy "won_select_own"
	on public.work_order_notifications
	for select
	to authenticated
	using (user_id = auth.uid ());

drop policy if exists "won_update_own" on public.work_order_notifications;

create policy "won_update_own"
	on public.work_order_notifications
	for update
	to authenticated
	using (user_id = auth.uid ())
	with check (user_id = auth.uid ());

-- -----------------------------------------------------------------------------
-- Storage policies
-- -----------------------------------------------------------------------------
drop policy if exists "work_orders_storage_admin" on storage.objects;

create policy "work_orders_storage_admin"
	on storage.objects
	for all
	to authenticated
	using (
		bucket_id = 'work-orders'
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	)
	with check (
		bucket_id = 'work-orders'
		and exists (
			select 1
			from public.profiles p
			where
				p.id = auth.uid ()
				and p.rol in ('ADMIN', 'SUPERADMIN')
		)
	);

drop policy if exists "work_orders_storage_assigned_read" on storage.objects;

create policy "work_orders_storage_assigned_read"
	on storage.objects
	for select
	to authenticated
	using (
		bucket_id = 'work-orders'
		and exists (
			select 1
			from public.work_order_assignments a
			join public.work_orders wo on wo.id = a.work_order_id
			where
				a.user_id = auth.uid ()
				and (
					storage.objects.name = wo.original_pdf_path
					or storage.objects.name like wo.id::text || '/%'
				)
		)
	);

drop policy if exists "work_orders_storage_assigned_write" on storage.objects;

create policy "work_orders_storage_assigned_write"
	on storage.objects
	for insert
	to authenticated
	with check (
		bucket_id = 'work-orders'
		and exists (
			select 1
			from public.work_order_assignments a
			where
				a.user_id = auth.uid ()
				and a.status = 'pending'
				and (storage.objects.name like a.work_order_id::text || '/%')
		)
	);
