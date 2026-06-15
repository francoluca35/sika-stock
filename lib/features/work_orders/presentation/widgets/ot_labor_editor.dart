import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../domain/work_order_form_rows.dart";
import "ot_form_theme.dart";

class OtLaborEditor extends StatefulWidget {
	const OtLaborEditor({
		super.key,
		required this.rows,
		required this.onChanged,
		this.enabled = true,
	});

	final List<OtLaborRow> rows;
	final ValueChanged<List<OtLaborRow>> onChanged;
	final bool enabled;

	@override
	State<OtLaborEditor> createState() => _OtLaborEditorState();
}

class _OtLaborEditorState extends State<OtLaborEditor> {
	final List<_LaborControllers> _ctrls = [];

	static const _headers = ["Fecha", "Nombre", "H.N", "H.E", "100%", "200%"];
	static const _minWidths = [88.0, 120.0, 48.0, 48.0, 48.0, 48.0];

	@override
	void initState() {
		super.initState();
		_syncFromRows(widget.rows);
	}

	@override
	void didUpdateWidget(OtLaborEditor oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.rows.length != widget.rows.length) {
			_disposeCtrls();
			_syncFromRows(widget.rows);
		}
	}

	void _syncFromRows(List<OtLaborRow> rows) {
		if (rows.isEmpty) {
			_addEmpty(silent: true);
			return;
		}
		for (final r in rows) {
			_ctrls.add(_LaborControllers.fromRow(r, _emit));
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
		setState(() => _ctrls.add(_LaborControllers.empty(_emit)));
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

	@override
	Widget build(BuildContext context) {
		final tableWidth = _minWidths.fold<double>(0, (a, b) => a + b) + 40;

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: SizedBox(
						width: tableWidth,
						child: Column(
							children: [
								_headerRow(),
								...List.generate(_ctrls.length, (i) => _dataRow(i)),
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
							"Agregar mano de obra",
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

	Widget _headerRow() {
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

	Widget _dataRow(int i) {
		final c = _ctrls[i];
		final ctrls = [c.date, c.name, c.normalHours, c.extraHours, c.hours100, c.hours200];
		return Container(
			color: i.isOdd ? OtFormTheme.tableRowAlt : Colors.white,
			padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
			child: Row(
				children: [
					...List.generate(6, (col) {
						return SizedBox(
							width: _minWidths[col],
							child: widget.enabled
									? TextField(
											controller: ctrls[col],
											style: const TextStyle(fontSize: 12),
											keyboardType: col >= 2
													? const TextInputType.numberWithOptions(decimal: true)
													: TextInputType.text,
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

class _LaborControllers {
	_LaborControllers._({
		required this.date,
		required this.name,
		required this.normalHours,
		required this.extraHours,
		required this.hours100,
		required this.hours200,
	});

	final TextEditingController date;
	final TextEditingController name;
	final TextEditingController normalHours;
	final TextEditingController extraHours;
	final TextEditingController hours100;
	final TextEditingController hours200;

	factory _LaborControllers.empty(VoidCallback onChanged) {
		final c = _LaborControllers._(
			date: TextEditingController(),
			name: TextEditingController(),
			normalHours: TextEditingController(),
			extraHours: TextEditingController(),
			hours100: TextEditingController(),
			hours200: TextEditingController(),
		);
		for (final ctrl in [c.date, c.name, c.normalHours, c.extraHours, c.hours100, c.hours200]) {
			ctrl.addListener(onChanged);
		}
		return c;
	}

	factory _LaborControllers.fromRow(OtLaborRow r, VoidCallback onChanged) {
		final c = _LaborControllers._(
			date: TextEditingController(text: r.date),
			name: TextEditingController(text: r.name),
			normalHours: TextEditingController(text: r.normalHours),
			extraHours: TextEditingController(text: r.extraHours),
			hours100: TextEditingController(text: r.hours100),
			hours200: TextEditingController(text: r.hours200),
		);
		for (final ctrl in [c.date, c.name, c.normalHours, c.extraHours, c.hours100, c.hours200]) {
			ctrl.addListener(onChanged);
		}
		return c;
	}

	OtLaborRow toRow() => OtLaborRow(
				date: date.text,
				name: name.text,
				normalHours: normalHours.text,
				extraHours: extraHours.text,
				hours100: hours100.text,
				hours200: hours200.text,
			);

	void dispose() {
		date.dispose();
		name.dispose();
		normalHours.dispose();
		extraHours.dispose();
		hours100.dispose();
		hours200.dispose();
	}
}
