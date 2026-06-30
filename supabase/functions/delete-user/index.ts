import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.4";

type Body = {
	userId: string;
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

	const { userId } = body;
	if (!userId?.trim()) {
		return new Response(JSON.stringify({ error: "Falta userId" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	const userIdTrim = userId.trim();
	const uuidRe =
		/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
	if (!uuidRe.test(userIdTrim)) {
		return new Response(JSON.stringify({ error: "userId inválido" }), {
			status: 400,
			headers: { ...corsHeaders, "Content-Type": "application/json" },
		});
	}

	if (userIdTrim === user.id) {
		return new Response(
			JSON.stringify({ error: "No podés eliminar tu propia cuenta" }),
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
		.eq("id", userIdTrim)
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
				error: "Solo SUPERADMIN puede eliminar usuarios con rol ADMIN o SUPERADMIN",
			}),
			{
				status: 403,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	const { error: delErr } = await adminAuth.auth.admin.deleteUser(userIdTrim);

	if (delErr) {
		const msg = delErr.message ?? "Error al eliminar usuario";
		const fkBlocked =
			msg.toLowerCase().includes("foreign key") ||
			msg.toLowerCase().includes("violates") ||
			msg.toLowerCase().includes("restrict");
		return new Response(
			JSON.stringify({
				error: fkBlocked
					? "No se puede eliminar: el usuario tiene órdenes o registros asociados en el sistema"
					: msg,
			}),
			{
				status: fkBlocked ? 409 : 400,
				headers: { ...corsHeaders, "Content-Type": "application/json" },
			},
		);
	}

	return new Response(JSON.stringify({ ok: true }), {
		status: 200,
		headers: { ...corsHeaders, "Content-Type": "application/json" },
	});
});
