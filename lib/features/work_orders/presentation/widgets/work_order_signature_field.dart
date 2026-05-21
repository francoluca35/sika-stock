import "dart:typed_data";

import "package:flutter/material.dart";
import "package:signature/signature.dart";

class WorkOrderSignatureField extends StatefulWidget {
	const WorkOrderSignatureField({super.key, required this.onChanged});

	final ValueChanged<Uint8List?> onChanged;

	@override
	State<WorkOrderSignatureField> createState() => _WorkOrderSignatureFieldState();
}

class _WorkOrderSignatureFieldState extends State<WorkOrderSignatureField> {
	final _controller = SignatureController(
		penStrokeWidth: 2,
		penColor: Colors.black87,
		exportBackgroundColor: Colors.white,
	);

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	Future<void> _export() async {
		if (_controller.isEmpty) {
			widget.onChanged(null);
			return;
		}
		final bytes = await _controller.toPngBytes();
		widget.onChanged(bytes);
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Container(
					height: 140,
					decoration: BoxDecoration(
						border: Border.all(color: Colors.grey.shade400),
						borderRadius: BorderRadius.circular(8),
						color: Colors.white,
					),
					child: ClipRRect(
						borderRadius: BorderRadius.circular(8),
						child: Signature(
							controller: _controller,
							backgroundColor: Colors.white,
						),
					),
				),
				const SizedBox(height: 8),
				Row(
					children: [
						TextButton(
							onPressed: () {
								_controller.clear();
								widget.onChanged(null);
							},
							child: const Text("Limpiar"),
						),
						const Spacer(),
						FilledButton(
							onPressed: _export,
							child: const Text("Confirmar firma"),
						),
					],
				),
			],
		);
	}
}
