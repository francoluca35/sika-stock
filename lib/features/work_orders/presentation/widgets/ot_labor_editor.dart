import "package:flutter/material.dart";

import "../../domain/work_order_form_rows.dart";
import "ot_dynamic_row_field.dart";

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
		setState(() {
			_ctrls[i].dispose();
			_ctrls.removeAt(i);
			if (_ctrls.isEmpty) _ctrls.add(_LaborControllers.empty(_emit));
		});
		_emit();
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				...List.generate(_ctrls.length, (i) {
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
													"Mano de obra ${i + 1}",
													style: const TextStyle(fontWeight: FontWeight.bold),
												),
												const Spacer(),
												if (widget.enabled && _ctrls.length > 1)
													OtRemoveRowButton(onPressed: () => _remove(i)),
											],
										),
										const SizedBox(height: 8),
										OtDynamicRowField(
											label: "Fecha",
											controller: _ctrls[i].date,
											hint: "dd/mm/aaaa",
										),
										OtDynamicRowField(label: "Nombre", controller: _ctrls[i].name),
										OtDynamicRowField(
											label: "Hs. normal",
											controller: _ctrls[i].normalHours,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
										),
										OtDynamicRowField(
											label: "Hs. extra",
											controller: _ctrls[i].extraHours,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
										),
										OtDynamicRowField(
											label: "Hs. 100%",
											controller: _ctrls[i].hours100,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
										),
										OtDynamicRowField(
											label: "Hs. 200%",
											controller: _ctrls[i].hours200,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
										),
									],
								),
							),
						),
					);
				}),
				if (widget.enabled)
					OtAddRowButton(label: "AGREGAR MANO DE OBRA", onPressed: () => _addEmpty()),
			],
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
