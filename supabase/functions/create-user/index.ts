import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.4";

type Body = {
	email: string;
	password: string;
	nombre: string;
	usuario: string;
	rol: string;
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

	const { data: profile, error: profErr } = await userClient
		.from("profiles")
		.select("rol")
		.eq("id", user.id)
		.maybeSingle();

	if (profErr || !profile) {
		return new Response(JSON.stringify({ error: "Sin perfil" }), {
			status: 403,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const callerRol = profile.rol as string;
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

	const { email, password, nombre, usuario, rol } = body;
	if (!email?.trim() || !password || !nombre?.trim() || !usuario?.trim() || !rol) {
		return new Response(JSON.stringify({ error: "Faltan campos" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	if (rol === "ADMIN") {
		return new Response(
			JSON.stringify({
				error:
					"El rol ADMIN no se asigna desde la aplicación; usar operaciones en base de datos.",
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
	];
	if (!allowed.includes(rol)) {
		return new Response(JSON.stringify({ error: "Rol inválido" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	if (rol === "SUPERADMIN" && callerRol !== "SUPERADMIN") {
		return new Response(
			JSON.stringify({ error: "Solo SUPERADMIN puede crear SUPERADMIN" }),
			{
				status: 403,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const adminAuth = createClient(supabaseUrl, serviceKey, {
		auth: { autoRefreshToken: false, persistSession: false },
	});

	const { data: created, error: createErr } = await adminAuth.auth.admin.createUser({
		email: email.trim().toLowerCase(),
		password,
		email_confirm: true,
		user_metadata: { nombre: nombre.trim(), usuario: usuario.trim() },
	});

	if (createErr || !created.user) {
		return new Response(
			JSON.stringify({ error: createErr?.message ?? "Error al crear usuario" }),
			{
				status: 400,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const uid = created.user.id;

	const { error: upErr } = await adminAuth.from("profiles").upsert(
		{
			id: uid,
			email: email.trim().toLowerCase(),
			nombre: nombre.trim(),
			usuario: usuario.trim(),
			rol,
		},
		{ onConflict: "id" },
	);

	if (upErr) {
		try {
			await adminAuth.auth.admin.deleteUser(uid);
		} catch {
			/* rollback best effort */
		}
		return new Response(JSON.stringify({ error: upErr.message }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	return new Response(JSON.stringify({ ok: true, userId: uid }), {
		status: 200,
		headers: { ...corsHeaders, "Content-Type": "application/json" },
	});
});
