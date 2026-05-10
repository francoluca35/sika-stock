-- Ajuste trigger: altas hechas con service_role (Edge Functions) pueden crear cualquier rol.
-- Los usuarios autenticados solo pueden insertar su propia fila y nunca con SUPERADMIN.

create or replace function public.profiles_guard_rol ()
returns trigger
language plpgsql
as $$
begin
	if tg_op = 'INSERT' then
		if auth.role () = 'service_role' then
			return new;
		end if;
		if auth.uid () is not distinct from new.id and new.rol <> 'SUPERADMIN' then
			return new;
		end if;
		raise exception 'Alta de perfil no permitida';
	end if;

	if tg_op = 'UPDATE' then
		if auth.role () = 'service_role' then
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
