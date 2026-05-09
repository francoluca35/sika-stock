import "package:flutter/material.dart";

/// Tokens de diseño alineados a mockups (amarillo / rojo / negro / blanco).
///
/// **Tailwind CSS** no se usa en Flutter: la UI es widgets + Canvas, no HTML/CSS.
/// Opciones equivalentes:
/// - Este archivo (tokens propios, mismo enfoque que `tailwind.config.js`).
/// - Paquete `tailwind_colors` (pub.dev) solo exporta la **paleta de colores**
///   de Tailwind como [Color], sin clases utility.

abstract final class AppTokens {
	// Primarios (cabeceras, CTAs principales)
	static const Color yellowHeader = Color(0xFFFFD700);
	static const Color yellowAccent = Color(0xFFF5CC00);

	// Alertas / eliminar / bajo stock
	static const Color redAction = Color(0xFFC00000);
	static const Color redMuted = Color(0xFFB91C1C);

	static const Color blackNav = Color(0xFF0A0A0A);
	static const Color whiteSurface = Color(0xFFFFFFFF);
	static const Color greyBorder = Color(0xFFE5E7EB);

	// Estados (badges)
	static const Color statusOk = Color(0xFF16A34A);
	static const Color statusWarn = Color(0xFFEAB308);
	static const Color statusPending = Color(0xFFC00000);
	static const Color statusDone = Color(0xFF111827);

	static const double radiusMd = 8;
	static const double radiusLg = 12;
	static const EdgeInsets padScreen = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}
