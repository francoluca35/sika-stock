import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_web_plugins/url_strategy.dart";

import "core/config/env.dart";
import "core/format/argentina_datetime.dart";
import "core/notifications/local_notification_service.dart";
import "core/realtime/app_realtime_shell.dart";
import "core/router/app_router.dart";
import "core/supabase/supabase_bootstrap.dart";
import "core/theme/app_scroll_behavior.dart";
import "core/theme/app_theme.dart";

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	if (kIsWeb) {
		usePathUrlStrategy();
	}
	ArgentinaDateTime.ensureInitialized();
	await Env.load();
	await SupabaseBootstrap.initialize();
	await LocalNotificationService.initialize();
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
			builder: (context, child) => ScrollConfiguration(
				behavior: AppScrollBehavior.material(),
				child: AppRealtimeShell(
					child: child ?? const SizedBox.shrink(),
				),
			),
		);
	}
}
