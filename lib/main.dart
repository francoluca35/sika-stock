import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/config/env.dart";
import "core/router/app_router.dart";
import "core/supabase/supabase_bootstrap.dart";
import "core/theme/app_theme.dart";

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await Env.load();
	await SupabaseBootstrap.initialize();
	runApp(
		const ProviderScope(
			child: SikaStockApp(),
		),
	);
}

class SikaStockApp extends ConsumerWidget {
	const SikaStockApp({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final router = ref.watch(goRouterProvider);
		return MaterialApp.router(
			title: "Sika Stock",
			debugShowCheckedModeBanner: false,
			theme: AppTheme.light(),
			routerConfig: router,
		);
	}
}
