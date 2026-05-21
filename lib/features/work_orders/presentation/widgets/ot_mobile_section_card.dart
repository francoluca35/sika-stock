import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Bloque colapsable optimizado para pulgar (móvil).
class OtMobileSectionCard extends StatelessWidget {
	const OtMobileSectionCard({
		super.key,
		required this.title,
		required this.icon,
		required this.child,
		this.subtitle,
		this.initiallyExpanded = true,
		this.trailingBadge,
	});

	final String title;
	final String? subtitle;
	final IconData icon;
	final Widget child;
	final bool initiallyExpanded;
	final Widget? trailingBadge;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.whiteSurface,
			borderRadius: BorderRadius.circular(AppTokens.radiusLg),
			elevation: 1,
			shadowColor: Colors.black12,
			child: Theme(
				data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
				child: ExpansionTile(
					initiallyExpanded: initiallyExpanded,
					tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
					childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
					leading: Container(
						width: 40,
						height: 40,
						decoration: BoxDecoration(
							color: AppTokens.yellowHeader.withValues(alpha: 0.55),
							borderRadius: BorderRadius.circular(10),
						),
						child: Icon(icon, color: Colors.black87, size: 22),
					),
					title: Text(
						title,
						style: const TextStyle(
							fontWeight: FontWeight.bold,
							fontSize: 15,
							color: Colors.black87,
						),
					),
					subtitle: subtitle == null
							? null
							: Text(
									subtitle!,
									style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
								),
					trailing: trailingBadge,
					children: [child],
				),
			),
		);
	}
}
