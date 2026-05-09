import "package:flutter/material.dart";

import "core/theme/app_theme.dart";

void main() {
	runApp(const SikaStockApp());
}

/// Raíz de la app. Riverpod / Supabase / GoRouter se enganchan acá en fases siguientes.
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
					"Proyecto inicial — Web · Android · iOS",
					style: Theme.of(context).textTheme.titleMedium,
					textAlign: TextAlign.center,
				),
			),
		);
	}
}
