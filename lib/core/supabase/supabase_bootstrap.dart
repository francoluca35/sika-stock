import "package:supabase_flutter/supabase_flutter.dart";

import "../config/env.dart";

abstract final class SupabaseBootstrap {
	static Future<void> initialize() async {
		await Supabase.initialize(
			url: Env.supabaseUrl,
			anonKey: Env.supabaseAnonKey,
			realtimeClientOptions: const RealtimeClientOptions(
				logLevel: RealtimeLogLevel.error,
			),
		);
	}
}
