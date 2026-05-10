import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Decoración común de campos (login / registro).
abstract final class AuthFieldStyles {
	static TextStyle get labelAbove => const TextStyle(
		fontWeight: FontWeight.bold,
		fontSize: 12,
		color: Colors.black87,
		letterSpacing: 0.3,
	);

	static InputDecoration outline({
		required String hintText,
		required IconData prefixIcon,
	}) {
		return InputDecoration(
			hintText: hintText,
			hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
			prefixIcon: Icon(prefixIcon, color: Colors.black54, size: 22),
			filled: true,
			fillColor: AppTokens.whiteSurface,
			contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
			border: OutlineInputBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				borderSide: const BorderSide(color: AppTokens.greyBorder),
			),
			enabledBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				borderSide: const BorderSide(color: AppTokens.greyBorder),
			),
			focusedBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.35)),
			),
		);
	}
}
