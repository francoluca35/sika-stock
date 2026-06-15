import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../domain/work_order_check_item.dart";
import "ot_form_theme.dart";

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
				"Marcá el trabajo realizado en el campo de abajo.",
				style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
			);
		}

		return Column(
			children: List.generate(items.length, (i) {
				final item = items[i];
				return Padding(
					padding: const EdgeInsets.only(bottom: 6),
					child: Material(
						color: item.done ? const Color(0xFFECFDF5) : OtFormTheme.innerSurface,
						borderRadius: BorderRadius.circular(8),
						child: CheckboxListTile(
							value: item.done,
							onChanged: enabled ? (v) => onChanged(i, v ?? false) : null,
							controlAffinity: ListTileControlAffinity.leading,
							contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
							dense: true,
							title: Text(
								item.label,
								style: TextStyle(
									fontSize: 13,
									fontWeight: FontWeight.w600,
									decoration: item.done ? TextDecoration.lineThrough : null,
									color: item.done ? Colors.grey.shade700 : Colors.black87,
								),
							),
							activeColor: AppTokens.redAction,
							checkColor: Colors.white,
							side: BorderSide(color: Colors.grey.shade500, width: 1.2),
						),
					),
				);
			}),
		);
	}
}
