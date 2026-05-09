import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/config/env.dart";
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

/// Raíz de la app. GoRouter y pantallas por rol en fases siguientes.
class SikaStockApp extends StatelessWidget {
	const SikaStockApp({super.key});

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			title: "Sika Stock",
			debugShowCheckedModeBanner: false,
			theme: AppTheme.light(),
			home: const _PlaceholderHome(),
		);
	}
}

class _PlaceholderHome extends StatelessWidget {
	const _PlaceholderHome();

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text("Sika Stock")),
			body: Center(
				child: Text(
					"Supabase conectado — Web · Android · iOS",
					style: Theme.of(context).textTheme.titleMedium,
					textAlign: TextAlign.center,
				),
			),
		);
	}
}
