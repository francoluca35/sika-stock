import "dart:typed_data";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/domain/profile_row.dart";
import "../../application/work_orders_providers.dart";

class WorkOrderNewScreen extends ConsumerStatefulWidget {
	const WorkOrderNewScreen({super.key});

	@override
	ConsumerState<WorkOrderNewScreen> createState() => _WorkOrderNewScreenState();
}

class _WorkOrderNewScreenState extends ConsumerState<WorkOrderNewScreen> {
	final _titleCtrl = TextEditingController();
	final _otCtrl = TextEditingController();
	Uint8List? _pdfBytes;
	String? _fileName;
	final Set<String> _selectedUserIds = {};
	bool _sending = false;

	@override
	void dispose() {
		_titleCtrl.dispose();
		_otCtrl.dispose();
		super.dispose();
	}

	Future<void> _pickPdf() async {
		final result = await FilePicker.pickFiles(
			type: FileType.custom,
			allowedExtensions: ["pdf"],
			withData: true,
		);
		if (result == null || result.files.isEmpty) return;
		final f = result.files.single;
		final bytes = f.bytes;
		if (bytes == null || bytes.isEmpty) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("No se pudo leer el PDF.")),
			);
			return;
		}
		setState(() {
			_pdfBytes = bytes;
			_fileName = f.name;
			if (_titleCtrl.text.trim().isEmpty) {
				_titleCtrl.text = f.name.replaceAll(RegExp(r"\.pdf$", caseSensitive: false), "");
			}
			final otMatch = RegExp(r"OT[-\s]?(\d+)", caseSensitive: false).firstMatch(f.name);
			if (otMatch != null && _otCtrl.text.trim().isEmpty) {
				_otCtrl.text = otMatch.group(1) ?? "";
			}
		});
	}

	String _profileLabel(ProfileRow p) {
		final n = p.nombre?.trim();
		if (n != null && n.isNotEmpty) return n;
		return p.usuario ?? p.email ?? p.id.substring(0, 8);
	}

	Future<void> _submit() async {
		if (_pdfBytes == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Seleccioná un archivo PDF.")),
			);
			return;
		}
		if (_titleCtrl.text.trim().isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Indicá un título.")),
			);
			return;
		}
		if (_selectedUserIds.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Seleccioná al menos un empleado.")),
			);
			return;
		}
		setState(() => _sending = true);
		try {
			final id = await ref.read(workOrdersRepositoryProvider).createWorkOrderWithAssignments(
						title: _titleCtrl.text.trim(),
						pdfBytes: _pdfBytes!,
						assigneeUserIds: _selectedUserIds.toList(),
						otNumber: _otCtrl.text.trim().isEmpty ? null : _otCtrl.text.trim(),
					);
			if (!mounted) return;
			final wo = await ref.read(workOrdersRepositoryProvider).fetchWorkOrderById(id);
			if (!mounted) return;
			if (wo != null && wo.pdfMetadata.hasAnyData) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text(
							"PDF leído: OT ${wo.pdfMetadata.orderNumber.isEmpty ? (wo.otNumber ?? "—") : wo.pdfMetadata.orderNumber}",
						),
					),
				);
			}
			if (!mounted) return;
			Navigator.of(context).pop(true);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo enviar: $e")),
			);
		} finally {
			if (mounted) setState(() => _sending = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final staffAsync = ref.watch(maintenanceStaffProfilesProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: const Text("Nueva OT", style: TextStyle(fontWeight: FontWeight.bold)),
			),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					OutlinedButton.icon(
						onPressed: _sending ? null : _pickPdf,
						icon: const Icon(Icons.picture_as_pdf_outlined),
						label: Text(_fileName ?? "Elegir PDF"),
					),
					const SizedBox(height: 16),
					TextField(
						controller: _titleCtrl,
						decoration: const InputDecoration(
							labelText: "Título",
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 12),
					TextField(
						controller: _otCtrl,
						decoration: const InputDecoration(
							labelText: "Nº OT (opcional)",
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 20),
					const Text(
						"Enviar a mantenimiento",
						style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
					),
					const SizedBox(height: 8),
					staffAsync.when(
						data: (profiles) {
							if (profiles.isEmpty) {
								return const Text("No hay usuarios con rol Mantenimiento.");
							}
							return Wrap(
								spacing: 8,
								runSpacing: 8,
								children: profiles.map((p) {
									final selected = _selectedUserIds.contains(p.id);
									return FilterChip(
										label: Text(_profileLabel(p)),
										selected: selected,
										onSelected: _sending
												? null
												: (v) {
														setState(() {
															if (v) {
																_selectedUserIds.add(p.id);
															} else {
																_selectedUserIds.remove(p.id);
															}
														});
													},
									);
								}).toList(),
							);
						},
						loading: () => const LinearProgressIndicator(),
						error: (e, _) => Text("Error: $e"),
					),
					const SizedBox(height: 24),
					FilledButton(
						onPressed: _sending ? null : _submit,
						style: FilledButton.styleFrom(
							backgroundColor: AppTokens.redAction,
							padding: const EdgeInsets.symmetric(vertical: 14),
						),
						child: _sending
								? const SizedBox(
										height: 22,
										width: 22,
										child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
									)
								: const Text(
										"ENVIAR OT",
										style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
									),
					),
				],
			),
		);
	}
}
