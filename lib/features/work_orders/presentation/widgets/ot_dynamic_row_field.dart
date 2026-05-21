import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Campo compacto para filas de materiales / mano de obra en móvil.
class OtDynamicRowField extends StatelessWidget {
	const OtDynamicRowField({
		super.key,
		required this.label,
		required this.controller,
		this.hint,
		this.keyboardType,
		this.maxLines = 1,
	});

	final String label;
	final TextEditingController controller;
	final String? hint;
	final TextInputType? keyboardType;
	final int maxLines;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 10),
			child: TextField(
				controller: controller,
				keyboardType: keyboardType,
				maxLines: maxLines,
				style: const TextStyle(fontSize: 15),
				decoration: InputDecoration(
					labelText: label,
					hintText: hint,
					isDense: true,
					contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
					border: const OutlineInputBorder(),
				),
			),
		);
	}
}

/// Botón ancho para agregar filas (área táctil cómoda).
class OtAddRowButton extends StatelessWidget {
	const OtAddRowButton({super.key, required this.label, required this.onPressed});

	final String label;
	final VoidCallback onPressed;

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			width: double.infinity,
			child: OutlinedButton.icon(
				onPressed: onPressed,
				icon: const Icon(Icons.add_circle_outline),
				label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
				style: OutlinedButton.styleFrom(
					padding: const EdgeInsets.symmetric(vertical: 14),
					foregroundColor: Colors.black87,
					side: const BorderSide(color: Colors.black87),
				),
			),
		);
	}
}

/// Icono eliminar fila.
class OtRemoveRowButton extends StatelessWidget {
	const OtRemoveRowButton({super.key, required this.onPressed});

	final VoidCallback onPressed;

	@override
	Widget build(BuildContext context) {
		return IconButton.filledTonal(
			onPressed: onPressed,
			icon: const Icon(Icons.delete_outline, color: AppTokens.redAction),
			tooltip: "Quitar fila",
			style: IconButton.styleFrom(
				backgroundColor: Colors.red.shade50,
			),
		);
	}
}
