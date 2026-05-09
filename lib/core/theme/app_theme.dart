import "package:flutter/material.dart";

import "app_tokens.dart";

abstract final class AppTheme {
	static ThemeData light() {
		final base = ThemeData(
			useMaterial3: true,
			brightness: Brightness.light,
			colorScheme: const ColorScheme.light(
				primary: AppTokens.yellowHeader,
				onPrimary: Colors.black87,
				secondary: AppTokens.redAction,
				onSecondary: Colors.white,
				surface: AppTokens.whiteSurface,
				onSurface: Colors.black87,
				error: AppTokens.redAction,
				onError: Colors.white,
			),
			appBarTheme: const AppBarTheme(
				centerTitle: false,
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				elevation: 0,
			),
			cardTheme: CardThemeData(
				elevation: 0,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					side: const BorderSide(color: AppTokens.greyBorder),
				),
			),
			inputDecorationTheme: InputDecorationTheme(
				border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				),
				filled: true,
				fillColor: AppTokens.whiteSurface,
			),
		);

		return base.copyWith(
			elevatedButtonTheme: ElevatedButtonThemeData(
				style: ElevatedButton.styleFrom(
					backgroundColor: AppTokens.yellowAccent,
					foregroundColor: Colors.black87,
					padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					),
				),
			),
			outlinedButtonTheme: OutlinedButtonThemeData(
				style: OutlinedButton.styleFrom(
					foregroundColor: Colors.black87,
					side: const BorderSide(color: AppTokens.greyBorder),
					padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					),
				),
			),
		);
	}
}
