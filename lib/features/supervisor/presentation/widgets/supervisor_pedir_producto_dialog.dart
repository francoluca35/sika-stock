import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../auth/presentation/widgets/auth_field_styles.dart";
import "../../../orders/domain/order_priority.dart";
import "../../../orders/presentation/widgets/mobile_sheet_select_field.dart";

/// Datos del pedido a pañol cuando el producto no está en catálogo.
class SupervisorPedirProductoData {
	const SupervisorPedirProductoData({
		required this.productName,
		required this.quantity,
		required this.productType,
		required this.priority,
		required this.destination,
	});

	final String productName;
	final int quantity;
	final String productType;
	final String priority;
	final String destination;
}

const _tiposProducto = [
	"Materiales",
	"Herramientas",
	"Repuestos",
	"Consumibles",
	"Otro",
];

Future<SupervisorPedirProductoData?> showSupervisorPedirProductoDialog({
	required BuildContext context,
	required String nombreInicial,
	int? cantidadInicial,
	String? destinoInicial,
}) {
	return showDialog<SupervisorPedirProductoData>(
		context: context,
		builder: (ctx) => _SupervisorPedirProductoDialog(
			nombreInicial: nombreInicial,
			cantidadInicial: cantidadInicial,
			destinoInicial: destinoInicial,
		),
	);
}

class _SupervisorPedirProductoDialog extends ConsumerStatefulWidget {
	const _SupervisorPedirProductoDialog({
		required this.nombreInicial,
		this.cantidadInicial,
		this.destinoInicial,
	});

	final String nombreInicial;
	final int? cantidadInicial;
	final String? destinoInicial;

	@override
	ConsumerState<_SupervisorPedirProductoDialog> createState() =>
			_SupervisorPedirProductoDialogState();
}

class _SupervisorPedirProductoDialogState
		extends ConsumerState<_SupervisorPedirProductoDialog> {
	final _formKey = GlobalKey<FormState>();
	late final TextEditingController _nombreCtrl;
	late final TextEditingController _cantidadCtrl;
	late final TextEditingController _destinoCtrl;

	String? _tipoProducto;
	OrderPriority? _prioridad;

	@override
	void initState() {
		super.initState();
		_nombreCtrl = TextEditingController(text: widget.nombreInicial);
		_cantidadCtrl = TextEditingController(
			text: (widget.cantidadInicial != null && widget.cantidadInicial! > 0)
					? widget.cantidadInicial.toString()
					: "1",
		);
		_destinoCtrl = TextEditingController(text: widget.destinoInicial ?? "");
	}

	@override
	void dispose() {
		_nombreCtrl.dispose();
		_cantidadCtrl.dispose();
		_destinoCtrl.dispose();
		super.dispose();
	}

	void _enviar() {
		if (!_formKey.currentState!.validate()) return;
		if (_tipoProducto == null || _prioridad == null) return;

		final cant = int.parse(_cantidadCtrl.text.trim());
		Navigator.pop(
			context,
			SupervisorPedirProductoData(
				productName: _nombreCtrl.text.trim(),
				quantity: cant,
				productType: _tipoProducto!,
				priority: _prioridad!.dbValue,
				destination: _destinoCtrl.text.trim(),
			),
		);
	}

	Widget _labeledField({required String label, required Widget field}) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			mainAxisSize: MainAxisSize.min,
			children: [
				Align(
					alignment: Alignment.centerLeft,
					child: Text(label, style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				field,
			],
		);
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text("Pedir producto a pañol"),
			content: SizedBox(
				width: 440,
				child: Form(
					key: _formKey,
					child: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text(
									"El producto no figura en el catálogo. Completá el pedido y se derivará a pañol.",
									style: TextStyle(
										fontSize: 13,
										color: Colors.grey.shade800,
										height: 1.35,
									),
								),
								const SizedBox(height: 16),
								_labeledField(
									label: "NOMBRE DEL PRODUCTO",
									field: TextFormField(
										controller: _nombreCtrl,
										textCapitalization: TextCapitalization.sentences,
										decoration: AuthFieldStyles.outline(
											hintText: "Nombre del producto",
											prefixIcon: Icons.label_outline,
										),
										validator: (v) {
											if ((v ?? "").trim().length < 2) return "Requerido";
											return null;
										},
									),
								),
								const SizedBox(height: 14),
								_labeledField(
									label: "CANTIDAD",
									field: TextFormField(
										controller: _cantidadCtrl,
										keyboardType: TextInputType.number,
										inputFormatters: [FilteringTextInputFormatter.digitsOnly],
										decoration: AuthFieldStyles.outline(
											hintText: "Cantidad",
											prefixIcon: Icons.numbers,
										),
										validator: (v) {
											final n = int.tryParse((v ?? "").trim());
											if (n == null || n < 1) return "Cantidad ≥ 1";
											return null;
										},
									),
								),
								const SizedBox(height: 14),
								_labeledField(
									label: "TIPO DE PRODUCTO",
									field: MobileSheetSelectFormField<String>(
										value: _tipoProducto,
										options: _tiposProducto,
										labelOf: (t) => t,
										hintText: "Seleccionar…",
										prefixIcon: Icons.category_outlined,
										title: "Tipo de producto",
										onChanged: (v) => setState(() => _tipoProducto = v),
										validator: (v) => v == null ? "Elegí un tipo" : null,
									),
								),
								const SizedBox(height: 14),
								_labeledField(
									label: "PRIORIDAD",
									field: MobileSheetSelectFormField<OrderPriority>(
										value: _prioridad,
										options: OrderPriority.values.toList(),
										labelOf: (p) => p.label,
										hintText: "Seleccionar…",
										prefixIcon: Icons.flag_outlined,
										title: "Prioridad",
										onChanged: (v) => setState(() => _prioridad = v),
										validator: (v) => v == null ? "Elegí prioridad" : null,
									),
								),
								const SizedBox(height: 14),
								_labeledField(
									label: "DESTINO / SECTOR",
									field: TextFormField(
										controller: _destinoCtrl,
										textCapitalization: TextCapitalization.sentences,
										decoration: AuthFieldStyles.outline(
											hintText: "Destino",
											prefixIcon: Icons.place_outlined,
										),
										validator: (v) {
											if ((v ?? "").trim().length < 2) return "Requerido";
											return null;
										},
									),
								),
							],
						),
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(context),
					child: const Text("Cancelar"),
				),
				FilledButton(
					onPressed: _enviar,
					child: const Text("Enviar a pañol"),
				),
			],
		);
	}
}
