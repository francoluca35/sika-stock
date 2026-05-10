import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Cabecera auth: amarillo, logo Sika (`assets/sika.png`), títulos centrados y corte en V abajo.
class LoginBrandHeader extends StatelessWidget {
	const LoginBrandHeader({
		super.key,
		this.showBack = false,
		this.onBack,
	});

	final bool showBack;
	final VoidCallback? onBack;

	static const String _logoAsset = "assets/sika.png";

	@override
	Widget build(BuildContext context) {
		return ClipPath(
			clipper: _LoginHeaderVNotchClipper(),
			child: Container(
				width: double.infinity,
				color: AppTokens.yellowHeader,
				child: SafeArea(
					bottom: false,
					child: Padding(
						padding: EdgeInsets.fromLTRB(showBack ? 4 : 20, showBack ? 4 : 16, 20, 36),
						child: Column(
							children: [
								if (showBack)
									Align(
										alignment: Alignment.centerLeft,
										child: IconButton(
											onPressed: onBack,
											icon: const Icon(Icons.arrow_back, color: Colors.black87),
											padding: EdgeInsets.zero,
											constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
										),
									)
								else
									const SizedBox(height: 8),
								SizedBox(
									height: 88,
									child: Center(
										child: Image.asset(
											_logoAsset,
											height: 88,
											fit: BoxFit.contain,
											filterQuality: FilterQuality.high,
											semanticLabel: "Logo Sika",
										),
									),
								),
								const SizedBox(height: 12),
								Text(
									"SISTEMA DE GESTIÓN",
									textAlign: TextAlign.center,
									style: TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 17,
										letterSpacing: 0.6,
										color: Colors.black.withValues(alpha: 0.87),
									),
								),
								const SizedBox(height: 6),
								Text(
									"MANTENIMIENTO INDUSTRIAL",
									textAlign: TextAlign.center,
									style: TextStyle(
										fontSize: 12.5,
										fontWeight: FontWeight.w600,
										letterSpacing: 0.4,
										color: Colors.black.withValues(alpha: 0.87),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}

/// Borde inferior con «V» suave hacia el centro (transición al panel blanco).
final class _LoginHeaderVNotchClipper extends CustomClipper<Path> {
	@override
	Path getClip(Size size) {
		const notchDepth = 18.0;
		const spread = 56.0;
		final w = size.width;
		final h = size.height;

		return Path()
			..moveTo(0, 0)
			..lineTo(w, 0)
			..lineTo(w, h - notchDepth)
			..lineTo(w / 2 + spread, h - notchDepth)
			..lineTo(w / 2, h)
			..lineTo(w / 2 - spread, h - notchDepth)
			..lineTo(0, h - notchDepth)
			..close();
	}

	@override
	bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
