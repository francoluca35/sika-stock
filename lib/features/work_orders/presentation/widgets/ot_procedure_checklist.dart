import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../domain/work_order_check_item.dart";

class OtProcedureChecklist extends StatelessWidget {
	const OtProcedureChecklist({
		super.key,
		required this.items,
		required this.onChanged,
		this.enabled = true,
	});

	final List<WorkOrderCheckItem> items;
	final void Function(int index, bool done) onChanged;
	final bool enabled;

	@override
	Widget build(BuildContext context) {
		if (items.isEmpty) {
			return Text(
				"No se detectaron pasos en el PDF. Completá la descripción del trabajo abajo.",
				style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
			);
		}

		return Column(
			children: List.generate(items.length, (i) {
				final item = items[i];
				return Material(
					color: item.done ? AppTokens.surfaceMuted : Colors.white,
					borderRadius: BorderRadius.circular(10),
					child: CheckboxListTile(
						value: item.done,
						onChanged: enabled ? (v) => onChanged(i, v ?? false) : null,
						controlAffinity: ListTileControlAffinity.leading,
						contentPadding: const EdgeInsets.symmetric(horizontal: 4),
						title: Text(
							item.label,
							style: TextStyle(
								fontSize: 14,
								fontWeight: FontWeight.w600,
								decoration: item.done ? TextDecoration.lineThrough : null,
								color: Colors.black87,
							),
						),
						activeColor: AppTokens.redAction,
					),
				);
			}),
		);
	}
}
