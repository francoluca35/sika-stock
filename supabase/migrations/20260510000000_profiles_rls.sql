-- public.profiles + RLS alineado con lib/features/auth/data/auth_repository.dart
--
-- Cómo aplicar: Supabase Dashboard → SQL → pegar y ejecutar (o CLI: supabase db push).
--
-- Si ya tenés tabla profiles con otro esquema, revisá diffs a mano antes de ejecutar.
--
-- Confirmación por email (Auth): si está activada y tras signUp no hay sesión,
-- el upsert desde Flutter puede fallar por RLS (no hay JWT). En desarrollo podés
-- desactivar "Confirm email"; en producción conviene trigger en auth.users o Edge Function.

-- -----------------------------------------------------------------------------
-- Tabla
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
	id uuid primary key references auth.users (id) on delete cascade,
	email text,
	nombre text,
	usuario text,
	rol text not null default 'MANTENIMIENTO'
		check (
			rol in (
				'MANTENIMIENTO',
				'SUPERVISOR',
				'PANOL',
				'COMPRAS',
				'ADMIN',
				'SUPERADMIN'
			)
		),
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Perfil de usuario; id = auth.users.id';

create index if not exists profiles_email_idx on public.profiles (lower (email));

-- -----------------------------------------------------------------------------
-- updated_at
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at ()
returns trigger
language plpgsql
as $$
begin
	new.updated_at := now();
	return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
	before update on public.profiles
	for each row
	execute procedure public.set_updated_at ();

-- -----------------------------------------------------------------------------
-- Seguridad: sin auto-SUPERADMIN ni cambio de rol desde la API (JWT usuario).
-- Asignar SUPERADMIN o cambiar roles: SQL Editor / service_role / migraciones.
-- -----------------------------------------------------------------------------
create or replace function public.profiles_guard_rol ()
returns trigger
language plpgsql
as $$
begin
	if tg_op = 'INSERT' then
		if new.rol = 'SUPERADMIN' then
			raise exception 'No se puede auto-asignar SUPERADMIN';
		end if;
		return new;
	end if;

	if tg_op = 'UPDATE' then
		if old.rol is distinct from new.rol then
			raise exception 'El rol no puede modificarse por la aplicación';
		end if;
		return new;
	end if;

	return new;
end;
$$;

drop trigger if exists profiles_guard_rol on public.profiles;
create trigger profiles_guard_rol
	before insert or update on public.profiles
	for each row
	execute procedure public.profiles_guard_rol ();

-- -----------------------------------------------------------------------------
-- RLS (sin DELETE: no hay política = nadie borra filas vía cliente autenticado)
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
	on public.profiles
	for select
	to authenticated
	using (auth.uid () = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
	on public.profiles
	for insert
	to authenticated
	with check (auth.uid () = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
	on public.profiles
	for update
	to authenticated
	using (auth.uid () = id)
	with check (auth.uid () = id);

drop policy if exists "profiles_delete_own" on public.profiles;
