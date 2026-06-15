import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Estilos del formulario OT (fondo claro + colores Sika).
abstract final class OtFormTheme {
	static const Color labelMuted = Color(0xFF64748B);
	static const Color innerSurface = Color(0xFFF8FAFC);
	static const Color tableHeaderBg = Color(0xFF1E293B);
	static const Color tableRowAlt = Color(0xFFF1F5F9);

	static TextStyle get sectionTitle => const TextStyle(
				fontSize: 12,
				fontWeight: FontWeight.w800,
				letterSpacing: 1.1,
				color: AppTokens.redAction,
			);

	static TextStyle get body => const TextStyle(
				fontSize: 14,
				fontWeight: FontWeight.w600,
				color: Colors.black87,
				height: 1.35,
			);

	static TextStyle get label => TextStyle(
				fontSize: 12,
				fontWeight: FontWeight.w600,
				color: labelMuted,
			);

	static TextStyle get value => const TextStyle(
				fontSize: 14,
				fontWeight: FontWeight.w700,
				color: Colors.black87,
			);

	static BoxDecoration get card => BoxDecoration(
				color: AppTokens.whiteSurface,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				border: Border.all(color: AppTokens.greyBorder),
				boxShadow: const [
					BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
				],
			);

	static BoxDecoration get innerCard => BoxDecoration(
				color: innerSurface,
				borderRadius: BorderRadius.circular(10),
				border: Border.all(color: AppTokens.greyBorder),
			);

	static InputDecoration input({String? hint, String? label}) => InputDecoration(
				hintText: hint,
				labelText: label,
				filled: true,
				fillColor: AppTokens.whiteSurface,
				contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
					borderSide: const BorderSide(color: AppTokens.redAction, width: 1.4),
				),
			);

	static InputDecoration tableCellInput() => InputDecoration(
				isDense: true,
				contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
				border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(6),
					borderSide: BorderSide(color: Colors.grey.shade300),
				),
				enabledBorder: OutlineInputBorder(
					borderRadius: BorderRadius.circular(6),
					borderSide: BorderSide(color: Colors.grey.shade300),
				),
			);
}

/// Chip estilo mock (Sika).
class OtFormChip extends StatelessWidget {
	const OtFormChip({
		super.key,
		required this.label,
		this.variant = OtChipVariant.outlineAccent,
	});

	final String label;
	final OtChipVariant variant;

	@override
	Widget build(BuildContext context) {
		final Color bg;
		final Color fg;
		final BorderSide? border;
		switch (variant) {
			case OtChipVariant.outlineAccent:
				bg = Colors.transparent;
				fg = AppTokens.redAction;
				border = const BorderSide(color: AppTokens.redAction, width: 1.2);
			case OtChipVariant.filledBlue:
				bg = AppTokens.roleMantenimientoBg;
				fg = Colors.white;
				border = null;
			case OtChipVariant.filledMuted:
				bg = const Color(0xFFE2E8F0);
				fg = Colors.black87;
				border = null;
		}
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(20),
				border: border != null ? Border.fromBorderSide(border) : null,
			),
			child: Text(
				label,
				style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
			),
		);
	}
}

enum OtChipVariant { outlineAccent, filledBlue, filledMuted }

/// Título de sección (rojo mayúsculas).
class OtSectionTitle extends StatelessWidget {
	const OtSectionTitle(this.text, {super.key});

	final String text;

	@override
	Widget build(BuildContext context) {
		return Text(text.toUpperCase(), style: OtFormTheme.sectionTitle);
	}
}

/// Header SIKA + OT (mock, fondo claro).
class OtFormHeader extends StatelessWidget {
	const OtFormHeader({
		super.key,
		required this.otLabel,
		this.company = "SIKA S.A.I.C",
		this.checklistProgress,
	});

	final String otLabel;
	final String company;
	final String? checklistProgress;

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: AppTokens.yellowHeader,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				border: Border.all(color: Colors.black26, width: 0.6),
			),
			child: Row(
				children: [
					Container(
						width: 44,
						height: 44,
						decoration: BoxDecoration(
							color: AppTokens.redAction,
							borderRadius: BorderRadius.circular(8),
						),
						child: const Icon(Icons.business, color: Colors.white, size: 26),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									company,
									style: const TextStyle(
										fontWeight: FontWeight.w800,
										fontSize: 16,
										color: Colors.black87,
									),
								),
								Text(
									otLabel,
									style: const TextStyle(
										fontWeight: FontWeight.w800,
										fontSize: 15,
										color: AppTokens.redAction,
									),
								),
								if (checklistProgress != null)
									Text(
										checklistProgress!,
										style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
									),
							],
						),
					),
				],
			),
		);
	}
}

/// Caja interior para descripción del trabajo.
class OtInnerPanel extends StatelessWidget {
	const OtInnerPanel({super.key, required this.child});

	final Widget child;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			padding: const EdgeInsets.all(12),
			decoration: OtFormTheme.innerCard,
			child: child,
		);
	}
}
