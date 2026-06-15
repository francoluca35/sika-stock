import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "ot_form_theme.dart";

/// Sección del formulario OT (card clara, título rojo).
class OtMobileSectionCard extends StatelessWidget {
	const OtMobileSectionCard({
		super.key,
		required this.title,
		required this.child,
		this.subtitle,
		this.initiallyExpanded = true,
		this.trailing,
		this.icon,
	});

	final String title;
	final String? subtitle;
	final IconData? icon;
	final Widget child;
	final bool initiallyExpanded;
	final Widget? trailing;

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: OtFormTheme.card,
			child: Theme(
				data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
				child: ExpansionTile(
					initiallyExpanded: initiallyExpanded,
					tilePadding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
					childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
					leading: icon == null
							? null
							: Container(
									width: 36,
									height: 36,
									decoration: BoxDecoration(
										color: OtFormTheme.innerSurface,
										borderRadius: BorderRadius.circular(8),
										border: Border.all(color: AppTokens.greyBorder),
									),
									child: Icon(icon, color: AppTokens.redAction, size: 20),
								),
					title: OtSectionTitle(title),
					subtitle: subtitle == null
							? null
							: Padding(
									padding: const EdgeInsets.only(top: 4),
									child: Text(
										subtitle!,
										style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
									),
								),
					trailing: trailing,
					children: [child],
				),
			),
		);
	}
}
