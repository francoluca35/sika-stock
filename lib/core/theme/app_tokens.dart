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

	/// Fondo de página (listados, tablas).
	static const Color surfacePage = Color(0xFFF1F5F9);

	/// Cabecera de tabla / bloques neutros.
	static const Color surfaceMuted = Color(0xFFF8FAFC);

	// Badges de rol (usuarios — paleta corporativa)
	static const Color roleComprasBg = Color(0xFF047857);
	static const Color roleComprasFg = Color(0xFFFFFFFF);
	static const Color rolePanolBg = Color(0xFFEAB308);
	static const Color rolePanolFg = Color(0xFF1C1917);
	static const Color roleMantenimientoBg = Color(0xFF1D4ED8);
	static const Color roleMantenimientoFg = Color(0xFFFFFFFF);
	/// Supervisor — naranja (badge listado usuarios).
	static const Color roleSupervisorBg = Color(0xFFEA580C);
	static const Color roleSupervisorFg = Color(0xFFFFFFFF);
	static const Color roleAdminBg = Color(0xFF111827);
	static const Color roleAdminFg = Color(0xFFFFFFFF);

	// Estados (badges)
	static const Color statusOk = Color(0xFF16A34A);
	static const Color statusWarn = Color(0xFFEAB308);
	static const Color statusPending = Color(0xFFC00000);
	static const Color statusDone = Color(0xFF111827);

	static const double radiusMd = 8;
	static const double radiusLg = 12;
	static const EdgeInsets padScreen = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

	/// Ancho máximo del área de contenido en pantallas anchas (web / desktop).
	static const double maxContentWidth = 1040;
}
