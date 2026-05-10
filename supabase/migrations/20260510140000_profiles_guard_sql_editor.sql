-- Permite INSERT/UPDATE de perfiles (incl. SUPERADMIN) cuando:
-- - service_role (Edge Functions), o
-- - sesión sin JWT de usuario (SQL Editor / scripts en Dashboard: auth.uid() IS NULL).
-- Los usuarios con JWT solo pueden insertar su fila sin SUPERADMIN y no pueden cambiar rol.

create or replace function public.profiles_guard_rol ()
returns trigger
language plpgsql
as $$
begin
	if tg_op = 'INSERT' then
		if auth.role () = 'service_role' then
			return new;
		end if;
		if auth.uid () is null then
			return new;
		end if;
		if auth.uid () is not distinct from new.id and new.rol <> 'SUPERADMIN' then
			return new;
		end if;
		raise exception 'Alta de perfil no permitida';
	end if;

	if tg_op = 'UPDATE' then
		if auth.role () = 'service_role' or auth.uid () is null then
			return new;
		end if;
		if old.rol is distinct from new.rol then
			raise exception 'El rol no puede modificarse por la aplicación';
		end if;
		return new;
	end if;

	return new;
end;
$$;
