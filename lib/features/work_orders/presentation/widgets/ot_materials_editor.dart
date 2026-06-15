import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../domain/work_order_form_rows.dart";
import "ot_form_theme.dart";

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

	static const _headers = ["Fecha", "Código", "Cant.", "Denominación", "Unidad", "Costo"];
	static const _minWidths = [88.0, 72.0, 56.0, 140.0, 56.0, 72.0];

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
		if (_ctrls.length <= 1) return;
		setState(() {
			_ctrls[i].dispose();
			_ctrls.removeAt(i);
		});
		_emit();
	}

	bool _rowEmpty(_MaterialControllers c) =>
			c.code.text.trim().isEmpty &&
			c.description.text.trim().isEmpty &&
			c.quantity.text.trim().isEmpty;

	@override
	Widget build(BuildContext context) {
		final tableWidth = _minWidths.fold<double>(0, (a, b) => a + b) + 48;

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: SizedBox(
						width: tableWidth,
						child: Column(
							children: [
								_tableHeader(),
								...List.generate(_ctrls.length, (i) => _tableRow(i)),
							],
						),
					),
				),
				if (widget.enabled) ...[
					const SizedBox(height: 12),
					OutlinedButton.icon(
						onPressed: () => _addEmpty(),
						icon: const Icon(Icons.add, size: 20),
						label: const Text(
							"Agregar material",
							style: TextStyle(fontWeight: FontWeight.w700),
						),
						style: OutlinedButton.styleFrom(
							foregroundColor: AppTokens.redAction,
							side: const BorderSide(color: AppTokens.redAction, width: 1.2),
							padding: const EdgeInsets.symmetric(vertical: 14),
						),
					),
				],
			],
		);
	}

	Widget _tableHeader() {
		return Container(
			padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
			decoration: const BoxDecoration(
				color: OtFormTheme.tableHeaderBg,
				borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
			),
			child: Row(
				children: List.generate(_headers.length, (i) {
					return SizedBox(
						width: _minWidths[i],
						child: Text(
							_headers[i],
							style: const TextStyle(
								color: Colors.white,
								fontWeight: FontWeight.w700,
								fontSize: 11,
							),
						),
					);
				}),
			),
		);
	}

	Widget _tableRow(int i) {
		final c = _ctrls[i];
		final alt = i.isOdd;
		final empty = _rowEmpty(c);
		final ctrls = [c.date, c.code, c.quantity, c.description, c.unit, c.cost];

		return Container(
			color: alt ? OtFormTheme.tableRowAlt : Colors.white,
			padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					...List.generate(6, (col) {
						return SizedBox(
							width: _minWidths[col],
							child: widget.enabled
									? TextField(
											controller: ctrls[col],
											style: TextStyle(
												fontSize: 12,
												fontStyle: empty && col > 1 ? FontStyle.italic : FontStyle.normal,
												color: empty && col > 1 ? Colors.grey : Colors.black87,
											),
											decoration: OtFormTheme.tableCellInput(),
										)
									: Text(
											ctrls[col].text.isEmpty ? "—" : ctrls[col].text,
											style: const TextStyle(fontSize: 12),
										),
						);
					}),
					if (widget.enabled && _ctrls.length > 1)
						IconButton(
							icon: const Icon(Icons.close, size: 18, color: AppTokens.redAction),
							onPressed: () => _remove(i),
							padding: EdgeInsets.zero,
							constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
						),
				],
			),
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
