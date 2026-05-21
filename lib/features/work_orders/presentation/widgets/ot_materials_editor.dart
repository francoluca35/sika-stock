import "package:flutter/material.dart";

import "../../domain/work_order_form_rows.dart";
import "ot_dynamic_row_field.dart";

class OtMaterialsEditor extends StatefulWidget {
	const OtMaterialsEditor({
		super.key,
		required this.rows,
		required this.onChanged,
		this.enabled = true,
	});

	final List<OtMaterialRow> rows;
	final ValueChanged<List<OtMaterialRow>> onChanged;
	final bool enabled;

	@override
	State<OtMaterialsEditor> createState() => _OtMaterialsEditorState();
}

class _OtMaterialsEditorState extends State<OtMaterialsEditor> {
	final List<_MaterialControllers> _ctrls = [];

	@override
	void initState() {
		super.initState();
		_syncFromRows(widget.rows);
	}

	@override
	void didUpdateWidget(OtMaterialsEditor oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.rows.length != widget.rows.length) {
			_disposeCtrls();
			_syncFromRows(widget.rows);
		}
	}

	void _syncFromRows(List<OtMaterialRow> rows) {
		if (rows.isEmpty) {
			_addEmpty(silent: true);
			return;
		}
		for (final r in rows) {
			_ctrls.add(_MaterialControllers.fromRow(r, _emit));
		}
	}

	void _disposeCtrls() {
		for (final c in _ctrls) {
			c.dispose();
		}
		_ctrls.clear();
	}

	@override
	void dispose() {
		_disposeCtrls();
		super.dispose();
	}

	void _emit() {
		widget.onChanged(_ctrls.map((c) => c.toRow()).toList());
	}

	void _addEmpty({bool silent = false}) {
		setState(() => _ctrls.add(_MaterialControllers.empty(_emit)));
		if (!silent) _emit();
	}

	void _remove(int i) {
		setState(() {
			_ctrls[i].dispose();
			_ctrls.removeAt(i);
			if (_ctrls.isEmpty) _ctrls.add(_MaterialControllers.empty(_emit));
		});
		_emit();
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				...List.generate(_ctrls.length, (i) {
					final c = _ctrls[i];
					return Padding(
						padding: const EdgeInsets.only(bottom: 14),
						child: Material(
							color: Colors.grey.shade50,
							borderRadius: BorderRadius.circular(10),
							child: Padding(
								padding: const EdgeInsets.all(12),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(
											children: [
												Text(
													"Material ${i + 1}",
													style: const TextStyle(fontWeight: FontWeight.bold),
												),
												const Spacer(),
												if (widget.enabled && _ctrls.length > 1)
													OtRemoveRowButton(onPressed: () => _remove(i)),
											],
										),
										const SizedBox(height: 8),
										OtDynamicRowField(label: "Fecha", controller: c.date, hint: "dd/mm/aaaa"),
										OtDynamicRowField(label: "Código", controller: c.code),
										OtDynamicRowField(
											label: "Cantidad",
											controller: c.quantity,
											keyboardType: TextInputType.number,
										),
										OtDynamicRowField(label: "Denominación", controller: c.description, maxLines: 2),
										OtDynamicRowField(label: "Unidad", controller: c.unit),
										OtDynamicRowField(
											label: "Costo",
											controller: c.cost,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
										),
									],
								),
							),
						),
					);
				}),
				if (widget.enabled)
					OtAddRowButton(label: "AGREGAR MATERIAL", onPressed: () => _addEmpty()),
			],
		);
	}
}

class _MaterialControllers {
	_MaterialControllers._({
		required this.date,
		required this.code,
		required this.quantity,
		required this.description,
		required this.unit,
		required this.cost,
	});

	final TextEditingController date;
	final TextEditingController code;
	final TextEditingController quantity;
	final TextEditingController description;
	final TextEditingController unit;
	final TextEditingController cost;

	factory _MaterialControllers.empty(VoidCallback onChanged) {
		final c = _MaterialControllers._(
			date: TextEditingController(),
			code: TextEditingController(),
			quantity: TextEditingController(),
			description: TextEditingController(),
			unit: TextEditingController(),
			cost: TextEditingController(),
		);
		for (final ctrl in [c.date, c.code, c.quantity, c.description, c.unit, c.cost]) {
			ctrl.addListener(onChanged);
		}
		return c;
	}

	factory _MaterialControllers.fromRow(OtMaterialRow r, VoidCallback onChanged) {
		final c = _MaterialControllers._(
			date: TextEditingController(text: r.date),
			code: TextEditingController(text: r.code),
			quantity: TextEditingController(text: r.quantity),
			description: TextEditingController(text: r.description),
			unit: TextEditingController(text: r.unit),
			cost: TextEditingController(text: r.cost),
		);
		for (final ctrl in [c.date, c.code, c.quantity, c.description, c.unit, c.cost]) {
			ctrl.addListener(onChanged);
		}
		return c;
	}

	OtMaterialRow toRow() => OtMaterialRow(
				date: date.text,
				code: code.text,
				quantity: quantity.text,
				description: description.text,
				unit: unit.text,
				cost: cost.text,
			);

	void dispose() {
		date.dispose();
		code.dispose();
		quantity.dispose();
		description.dispose();
		unit.dispose();
		cost.dispose();
	}
}
