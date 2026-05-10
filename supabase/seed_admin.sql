-- Después de crear el usuario en Dashboard → Authentication → Users
-- (email francolucap1@gmail.com y la contraseña que definiste),
-- ejecutá esto para dejar el perfil como SUPERADMIN y poder usar «Nuevos usuarios».

insert into public.profiles (id, email, nombre, usuario, rol)
select
	u.id,
	u.email,
	coalesce(
		nullif(trim(u.raw_user_meta_data ->> 'nombre'), ''),
		'Administrador'
	),
	coalesce(
		nullif(trim(u.raw_user_meta_data ->> 'usuario'), ''),
		nullif(split_part(lower(trim(u.email)), '@', 1), ''),
		'admin'
	),
	'SUPERADMIN'
from auth.users u
where lower(u.email) = lower('francolucap1@gmail.com')
on conflict (id) do update
set
	email = excluded.email,
	rol = 'SUPERADMIN',
	nombre = coalesce(nullif(trim(public.profiles.nombre), ''), excluded.nombre),
	usuario = coalesce(nullif(trim(public.profiles.usuario), ''), excluded.usuario);
