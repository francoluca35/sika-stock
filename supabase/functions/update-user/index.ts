import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.4";

type Body = {
	userId: string;
	email: string;
	nombre: string;
	usuario: string;
	rol: string;
	password?: string;
};

const corsHeaders: Record<string, string> = {
	"Access-Control-Allow-Origin": "*",
	"Access-Control-Allow-Methods": "POST, OPTIONS",
	"Access-Control-Allow-Headers":
		"authorization, x-client-info, apikey, content-type",
	"Access-Control-Max-Age": "86400",
};

Deno.serve(async (req: Request) => {
	if (req.method === "OPTIONS") {
		return new Response(null, { status: 204, headers: corsHeaders });
	}

	if (req.method !== "POST") {
		return new Response(JSON.stringify({ error: "Method not allowed" }), {
			status: 405,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const authHeader = req.headers.get("Authorization");
	if (!authHeader?.startsWith("Bearer ")) {
		return new Response(JSON.stringify({ error: "Unauthorized" }), {
			status: 401,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const accessToken = authHeader.replace(/^Bearer\s+/i, "").trim();
	if (!accessToken) {
		return new Response(JSON.stringify({ error: "Unauthorized" }), {
			status: 401,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
	const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
	const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

	const bearerUser = `Bearer ${accessToken}`;
	const userClient = createClient(supabaseUrl, anonKey, {
		global: {
			headers: {
				Authorization: bearerUser,
				apikey: anonKey,
			},
		},
	});

	const {
		data: { user },
		error: userErr,
	} = await userClient.auth.getUser(accessToken);
	if (userErr || !user) {
		return new Response(JSON.stringify({ error: "Invalid session" }), {
			status: 401,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const { data: callerProfile, error: profErr } = await userClient
		.from("profiles")
		.select("rol")
		.eq("id", user.id)
		.maybeSingle();

	if (profErr || !callerProfile) {
		return new Response(JSON.stringify({ error: "Sin perfil" }), {
			status: 403,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const callerRol = callerProfile.rol as string;
	if (!["ADMIN", "SUPERADMIN"].includes(callerRol)) {
		return new Response(JSON.stringify({ error: "Forbidden" }), {
			status: 403,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	let body: Body;
	try {
		body = (await req.json()) as Body;
	} catch {
		return new Response(JSON.stringify({ error: "JSON inválido" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const { userId, email, nombre, usuario, rol } = body;
	const password =
		typeof body.password === "string" && body.password.length > 0
			? body.password
			: undefined;

	if (!userId?.trim() || !email?.trim() || !nombre?.trim() || !usuario?.trim() || !rol) {
		return new Response(JSON.stringify({ error: "Faltan campos" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const uuidRe =
		/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
	if (!uuidRe.test(userId.trim())) {
		return new Response(JSON.stringify({ error: "userId inválido" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	if (password !== undefined && password.length < 6) {
		return new Response(
			JSON.stringify({ error: "La contraseña debe tener al menos 6 caracteres" }),
			{
				status: 400,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const adminAuth = createClient(supabaseUrl, serviceKey, {
		auth: { autoRefreshToken: false, persistSession: false },
	});

	const { data: targetProf, error: targetErr } = await adminAuth
		.from("profiles")
		.select("rol")
		.eq("id", userId.trim())
		.maybeSingle();

	if (targetErr || !targetProf) {
		return new Response(JSON.stringify({ error: "Usuario no encontrado" }), {
			status: 404,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const targetRol = targetProf.rol as string;

	if (["ADMIN", "SUPERADMIN"].includes(targetRol) && callerRol !== "SUPERADMIN") {
		return new Response(
			JSON.stringify({
				error: "Solo SUPERADMIN puede editar usuarios con rol ADMIN o SUPERADMIN",
			}),
			{
				status: 403,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const allowed = [
		"MANTENIMIENTO",
		"SUPERVISOR",
		"PANOL",
		"COMPRAS",
		"SUPERADMIN",
		"ADMIN",
	];
	if (!allowed.includes(rol)) {
		return new Response(JSON.stringify({ error: "Rol inválido" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	if (rol === "ADMIN") {
		if (callerRol !== "SUPERADMIN") {
			return new Response(JSON.stringify({ error: "Forbidden" }), {
				status: 403,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			});
		}
		if (targetRol !== "ADMIN") {
			return new Response(
				JSON.stringify({
					error: "No se puede asignar rol ADMIN desde la aplicación",
				}),
				{
					status: 403,
					headers: { ...corsHeaders, "Content-Type": "application/json" },
				},
			);
		}
	}

	if (rol === "SUPERADMIN" && callerRol !== "SUPERADMIN") {
		return new Response(JSON.stringify({ error: "Forbidden" }), {
			status: 403,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	if (rol === "SUPERADMIN" && targetRol !== "SUPERADMIN") {
		return new Response(
			JSON.stringify({
				error: "No se puede asignar SUPERADMIN desde la aplicación",
			}),
			{
				status: 403,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const emailNorm = email.trim().toLowerCase();
	const nombreTrim = nombre.trim();
	const usuarioTrim = usuario.trim();

	const updatePayload: {
		email?: string;
		password?: string;
		user_metadata?: Record<string, string>;
	} = {
		email: emailNorm,
		user_metadata: {
			nombre: nombreTrim,
			usuario: usuarioTrim,
		},
	};
	if (password !== undefined) {
		updatePayload.password = password;
	}

	const { error: authErr } = await adminAuth.auth.admin.updateUserById(
		userId.trim(),
		updatePayload,
	);

	if (authErr) {
		return new Response(
			JSON.stringify({ error: authErr.message ?? "Error al actualizar credenciales" }),
			{
				status: 400,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const { error: upErr } = await adminAuth
		.from("profiles")
		.update({
			email: emailNorm,
			nombre: nombreTrim,
			usuario: usuarioTrim,
			rol,
		})
		.eq("id", userId.trim());

	if (upErr) {
		return new Response(JSON.stringify({ error: upErr.message }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	return new Response(JSON.stringify({ ok: true }), {
		status: 200,
		headers: { ...corsHeaders, "Content-Type": "application/json" },
	});
});
