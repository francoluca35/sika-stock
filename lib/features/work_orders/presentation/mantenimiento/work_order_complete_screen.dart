import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../../auth/application/auth_providers.dart";
import "../../application/work_orders_providers.dart";
import "../../data/work_order_pdf_metadata_parser.dart";
import "../../domain/work_order_check_item.dart";
import "../../domain/work_order_form_rows.dart";
import "../../domain/work_order_pdf_metadata.dart";
import "../widgets/ot_labor_editor.dart";
import "../widgets/ot_materials_editor.dart";
import "../widgets/ot_mobile_section_card.dart";
import "../widgets/ot_order_info_section.dart";
import "../widgets/ot_procedure_checklist.dart";
import "../widgets/work_order_pdf_open.dart";
import "../widgets/work_order_pdf_viewer_page.dart";
import "../widgets/work_order_signature_field.dart";

/// Formulario móvil para completar OT (técnico). El PDF lo sube el admin.
class WorkOrderCompleteScreen extends ConsumerStatefulWidget {
	const WorkOrderCompleteScreen({super.key, required this.assignmentId});

	final String assignmentId;

	@override
	ConsumerState<WorkOrderCompleteScreen> createState() => _WorkOrderCompleteScreenState();
}

class _WorkOrderCompleteScreenState extends ConsumerState<WorkOrderCompleteScreen> {
	final _tasksCtrl = TextEditingController();
	final _obsCtrl = TextEditingController();
	final _workDoneCtrl = TextEditingController();

	Uint8List? _pdfBytes;
	WorkOrderPdfMetadata _metadata = const WorkOrderPdfMetadata();
	String? _otNumber;
	String _receiverName = "";
	List<WorkOrderCheckItem> _checklist = [];
	List<OtMaterialRow> _materials = [];
	List<OtLaborRow> _labor = [];
	String _counterState = "";
	DateTime? _startedAt;
	DateTime? _finishedAt;
	Uint8List? _signaturePng;
	final List<Uint8List> _attachments = [];
	bool _loading = true;
	bool _sending = false;

	@override
	void dispose() {
		_tasksCtrl.dispose();
		_obsCtrl.dispose();
		_workDoneCtrl.dispose();
		super.dispose();
	}

	@override
	void initState() {
		super.initState();
		_load();
	}

	WorkOrderPdfMetadata _mergeMetadata(WorkOrderPdfMetadata stored, WorkOrderPdfMetadata parsed) {
		return WorkOrderPdfMetadata(
			company: stored.company.isNotEmpty ? stored.company : parsed.company,
			plant: stored.plant.isNotEmpty ? stored.plant : parsed.plant,
			sector: stored.sector.isNotEmpty ? stored.sector : parsed.sector,
			location: stored.location.isNotEmpty ? stored.location : parsed.location,
			orderType: stored.orderType.isNotEmpty ? stored.orderType : parsed.orderType,
			date: stored.date.isNotEmpty ? stored.date : parsed.date,
			responsible: stored.responsible.isNotEmpty ? stored.responsible : parsed.responsible,
			orderNumber: stored.orderNumber.isNotEmpty ? stored.orderNumber : parsed.orderNumber,
			receiver: _receiverName,
			tolerance: stored.tolerance.isNotEmpty ? stored.tolerance : parsed.tolerance,
			workDescription: stored.workDescription.isNotEmpty ? stored.workDescription : parsed.workDescription,
			procedure: stored.procedure.isNotEmpty ? stored.procedure : parsed.procedure,
			requestedBy: stored.requestedBy.isNotEmpty ? stored.requestedBy : parsed.requestedBy,
			priority: stored.priority.isNotEmpty ? stored.priority : parsed.priority,
			procedureSteps: stored.procedureSteps.isNotEmpty ? stored.procedureSteps : parsed.procedureSteps,
		);
	}

	Future<void> _load() async {
		try {
			final a = await ref.read(workOrdersRepositoryProvider).fetchAssignmentById(widget.assignmentId);
			final wo = a?.workOrder;
			if (wo != null) {
				_otNumber = wo.otNumber;
				_receiverName = a?.assigneeName ?? "";
				if (_receiverName.isEmpty) {
					final profile = await ref.read(currentProfileProvider.future);
					_receiverName = profile?.nombre?.trim().isNotEmpty == true
							? profile!.nombre!.trim()
							: (profile?.usuario ?? "");
				}
				final bytes = await ref.read(workOrdersRepositoryProvider).downloadStorageBytes(
							wo.originalPdfPath,
						);
				var meta = wo.pdfMetadata;
				if (bytes.isNotEmpty) {
					final parsed = WorkOrderPdfMetadataParser.parseFromPdfBytes(bytes);
					meta = _mergeMetadata(meta, parsed);
					_pdfBytes = bytes;
				}
				_metadata = meta.withReceiver(_receiverName);
				_checklist = WorkOrderCheckItem.fromProcedureSteps(_metadata.procedureSteps);
				_workDoneCtrl.text = _metadata.workDescription;
				final now = DateTime.now();
				_startedAt = now;
				_finishedAt = now;
				_labor = [
					OtLaborRow(
						date: ArgentinaDateTime.formatDateOnly(now),
						name: _receiverName,
					),
				];
			}
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Future<void> _openPdfOnPhone() async {
		if (_pdfBytes == null) return;
		final ok = await openPdfExternally(_pdfBytes!, otNumber: _metadata.orderNumber);
		if (!mounted) return;
		if (!ok) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("No hay visor PDF. Usá «Ver en pantalla».")),
			);
		}
	}

	void _openPdfInApp() {
		if (_pdfBytes == null) return;
		openWorkOrderPdfViewer(context, _pdfBytes!, otNumber: _metadata.orderNumber);
	}

	Future<void> _pickImages() async {
		final picker = ImagePicker();
		final files = await picker.pickMultiImage(imageQuality: 85);
		if (files.isEmpty) return;
		final added = <Uint8List>[];
		for (final f in files) {
			final b = await f.readAsBytes();
			if (b.isNotEmpty) added.add(b);
		}
		if (!mounted || added.isEmpty) return;
		setState(() => _attachments.addAll(added));
	}

	Future<void> _pickDate({required bool start}) async {
		final initial = (start ? _startedAt : _finishedAt) ?? DateTime.now();
		final picked = await showDatePicker(
			context: context,
			initialDate: initial,
			firstDate: DateTime(2020),
			lastDate: DateTime(2100),
		);
		if (picked == null) return;
		setState(() {
			if (start) {
				_startedAt = picked;
			} else {
				_finishedAt = picked;
			}
		});
	}

	int get _checklistDone => _checklist.where((c) => c.done).length;

	Future<void> _submit() async {
		if (_signaturePng == null || _signaturePng!.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Confirmá tu firma antes de enviar.")),
			);
			return;
		}
		if (_startedAt == null || _finishedAt == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Indicá fecha de inicio y fin.")),
			);
			return;
		}

		final assignment = await ref.read(workOrdersRepositoryProvider).fetchAssignmentById(
					widget.assignmentId,
				);
		if (assignment == null || !assignment.isPending) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Esta OT ya fue enviada.")),
			);
			return;
		}
		final profile = await ref.read(currentProfileProvider.future);
		final name = profile?.nombre?.trim().isNotEmpty == true
				? profile!.nombre!.trim()
				: (profile?.usuario ?? "Mantenimiento");

		final formData = WorkOrderFormData(
			workDescription: _workDoneCtrl.text,
			tasksNews: _tasksCtrl.text,
			observations: _obsCtrl.text,
			materials: _materials.where((m) => _rowHasMaterial(m)).toList(),
			labor: _labor.where((l) => l.name.trim().isNotEmpty).toList(),
			counterState: _counterState,
			startedAtIso: _startedAt!.toUtc().toIso8601String(),
			finishedAtIso: _finishedAt!.toUtc().toIso8601String(),
		);

		setState(() => _sending = true);
		try {
			await ref.read(workOrdersRepositoryProvider).submitAssignmentResponse(
						assignment: assignment,
						assigneeName: name,
						formData: formData,
						checklist: _checklist,
						signaturePng: _signaturePng!,
						attachmentImages: _attachments,
					);
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

	static bool _rowHasMaterial(OtMaterialRow m) =>
			m.code.trim().isNotEmpty ||
			m.description.trim().isNotEmpty ||
			m.quantity.trim().isNotEmpty;

	Widget _pdfHeaderActions() {
		if (_pdfBytes == null) {
			return Text(
				"PDF no disponible. Pedí al administrador que vuelva a subir la OT.",
				style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
			);
		}
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				FilledButton.icon(
					onPressed: _openPdfOnPhone,
					icon: const Icon(Icons.picture_as_pdf),
					label: const Text(
						"VER PDF ORIGINAL",
						style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
					),
					style: FilledButton.styleFrom(
						backgroundColor: AppTokens.redAction,
						foregroundColor: Colors.white,
						padding: const EdgeInsets.symmetric(vertical: 16),
					),
				),
				const SizedBox(height: 8),
				OutlinedButton.icon(
					onPressed: _openPdfInApp,
					icon: const Icon(Icons.fullscreen),
					label: const Text("Ver en pantalla"),
					style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
				),
			],
		);
	}

	Widget _dateTile({
		required String label,
		required DateTime? value,
		required VoidCallback onTap,
	}) {
		return ListTile(
			contentPadding: EdgeInsets.zero,
			title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
			subtitle: Text(
				value == null ? "Elegir fecha" : ArgentinaDateTime.formatDateOnly(value),
				style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
			),
			trailing: const Icon(Icons.calendar_today_outlined),
			onTap: _sending ? null : onTap,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(8),
				side: BorderSide(color: Colors.grey.shade400),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) {
			return Scaffold(
				backgroundColor: AppTokens.surfacePage,
				appBar: AppBar(
					backgroundColor: AppTokens.yellowHeader,
					title: const Text("Completar OT", style: TextStyle(fontWeight: FontWeight.bold)),
				),
				body: const Center(child: CircularProgressIndicator()),
			);
		}

		final otLabel = _metadata.orderNumber.isNotEmpty
				? "OT ${_metadata.orderNumber}"
				: (_otNumber != null ? "OT $_otNumber" : "Orden de trabajo");

		final form = ListView(
			padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
			children: [
				Material(
					color: AppTokens.yellowHeader.withValues(alpha: 0.35),
					borderRadius: BorderRadius.circular(12),
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
						child: Row(
							children: [
								const Icon(Icons.assignment_outlined, size: 28),
								const SizedBox(width: 10),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												otLabel,
												style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
											),
											Text(
												"Checklist $_checklistDone/${_checklist.length}",
												style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
											),
										],
									),
								),
							],
						),
					),
				),
				const SizedBox(height: 12),
				_pdfHeaderActions(),
				const SizedBox(height: 16),
				OtMobileSectionCard(
					title: "Información de la orden",
					icon: Icons.info_outline,
					subtitle: "Datos leídos del PDF",
					child: OtOrderInfoSection(metadata: _metadata, otNumberFallback: _otNumber),
				),
				const SizedBox(height: 12),
				OtMobileSectionCard(
					title: "Descripción y checklist",
					icon: Icons.checklist_rtl,
					subtitle: "Marcá cada paso del procedimiento",
					trailingBadge: Chip(
						label: Text("$_checklistDone/${_checklist.length}"),
						padding: EdgeInsets.zero,
						materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							if (_metadata.workDescription.isNotEmpty) ...[
								Text(
									"Texto del PDF",
									style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
								),
								const SizedBox(height: 4),
								Text(
									_metadata.workDescription,
									style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
								),
								const SizedBox(height: 14),
							],
							OtProcedureChecklist(
								items: _checklist,
								enabled: !_sending,
								onChanged: (i, done) {
									setState(() {
										_checklist[i] = _checklist[i].copyWith(done: done);
									});
								},
							),
							const SizedBox(height: 16),
							const Text(
								"Trabajo realizado",
								style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
							),
							const SizedBox(height: 6),
							TextField(
								controller: _workDoneCtrl,
								maxLines: 5,
								enabled: !_sending,
								style: const TextStyle(fontSize: 15),
								decoration: const InputDecoration(
									hintText: "Detalle lo ejecutado en planta…",
									border: OutlineInputBorder(),
									alignLabelWithHint: true,
								),
							),
						],
					),
				),
				const SizedBox(height: 12),
				OtMobileSectionCard(
					title: "Novedades y tareas",
					icon: Icons.note_alt_outlined,
					initiallyExpanded: false,
					child: TextField(
						controller: _tasksCtrl,
						maxLines: 5,
						enabled: !_sending,
						style: const TextStyle(fontSize: 15),
						decoration: const InputDecoration(
							hintText: "Novedades, tareas fuera de programa, repuestos…",
							border: OutlineInputBorder(),
							alignLabelWithHint: true,
						),
					),
				),
				const SizedBox(height: 12),
				OtMobileSectionCard(
					title: "Materiales utilizados",
					icon: Icons.inventory_2_outlined,
					initiallyExpanded: false,
					child: OtMaterialsEditor(
						rows: _materials,
						enabled: !_sending,
						onChanged: (rows) => setState(() => _materials = rows),
					),
				),
				const SizedBox(height: 12),
				OtMobileSectionCard(
					title: "Mano de obra",
					icon: Icons.engineering_outlined,
					initiallyExpanded: false,
					child: OtLaborEditor(
						rows: _labor,
						enabled: !_sending,
						onChanged: (rows) => setState(() => _labor = rows),
					),
				),
				const SizedBox(height: 12),
				OtMobileSectionCard(
					title: "Cierre y firma",
					icon: Icons.flag_outlined,
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							_dateTile(
								label: "Fecha inicio",
								value: _startedAt,
								onTap: () => _pickDate(start: true),
							),
							const SizedBox(height: 10),
							_dateTile(
								label: "Fecha fin",
								value: _finishedAt,
								onTap: () => _pickDate(start: false),
							),
							const SizedBox(height: 14),
							const Text("Estado contador", style: TextStyle(fontWeight: FontWeight.bold)),
							const SizedBox(height: 8),
							DropdownButtonFormField<String>(
								value: _counterState.isEmpty ? "" : _counterState,
								decoration: const InputDecoration(border: OutlineInputBorder()),
								items: OtCounterStates.options
										.map(
											(v) => DropdownMenuItem(
												value: v,
												child: Text(OtCounterStates.label(v)),
											),
										)
										.toList(),
								onChanged: _sending
										? null
										: (v) => setState(() => _counterState = v ?? ""),
							),
							const SizedBox(height: 14),
							TextField(
								controller: _obsCtrl,
								maxLines: 3,
								enabled: !_sending,
								style: const TextStyle(fontSize: 15),
								decoration: const InputDecoration(
									labelText: "Observaciones",
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 12),
							OutlinedButton.icon(
								onPressed: _sending ? null : _pickImages,
								icon: const Icon(Icons.camera_alt_outlined),
								label: Text(
									_attachments.isEmpty
											? "SACAR / ADJUNTAR FOTOS"
											: "FOTOS (${_attachments.length})",
								),
								style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
							),
							if (_attachments.isNotEmpty)
								Padding(
									padding: const EdgeInsets.only(top: 10),
									child: Wrap(
										spacing: 8,
										runSpacing: 8,
										children: List.generate(_attachments.length, (i) {
											return Stack(
												clipBehavior: Clip.none,
												children: [
													ClipRRect(
														borderRadius: BorderRadius.circular(8),
														child: Image.memory(
															_attachments[i],
															width: 88,
															height: 88,
															fit: BoxFit.cover,
														),
													),
													Positioned(
														top: -6,
														right: -6,
														child: IconButton(
															style: IconButton.styleFrom(
																backgroundColor: Colors.black87,
																foregroundColor: Colors.white,
																minimumSize: const Size(28, 28),
																padding: EdgeInsets.zero,
															),
															onPressed: _sending
																	? null
																	: () => setState(() => _attachments.removeAt(i)),
															icon: const Icon(Icons.close, size: 16),
														),
													),
												],
											);
										}),
									),
								),
							const SizedBox(height: 16),
							const Text("Firma de confirmación", style: TextStyle(fontWeight: FontWeight.bold)),
							const SizedBox(height: 8),
							WorkOrderSignatureField(
								onChanged: (b) => setState(() => _signaturePng = b),
							),
						],
					),
				),
			],
		);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: Text(
					otLabel,
					style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
				),
			),
			body: Column(
				children: [
					Expanded(child: form),
					Material(
						elevation: 10,
						color: Colors.white,
						child: SafeArea(
							top: false,
							child: Padding(
								padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
								child: SizedBox(
									width: double.infinity,
									child: FilledButton(
										onPressed: _sending ? null : _submit,
										style: FilledButton.styleFrom(
											backgroundColor: AppTokens.redAction,
											padding: const EdgeInsets.symmetric(vertical: 18),
											shape: RoundedRectangleBorder(
												borderRadius: BorderRadius.circular(AppTokens.radiusMd),
											),
										),
										child: _sending
												? const SizedBox(
														height: 24,
														width: 24,
														child: CircularProgressIndicator(
															strokeWidth: 2,
															color: Colors.white,
														),
													)
												: const Text(
														"ENVIAR OT COMPLETADA",
														style: TextStyle(
															fontWeight: FontWeight.bold,
															color: Colors.white,
															fontSize: 16,
															letterSpacing: 0.3,
														),
													),
									),
								),
							),
						),
					),
				],
			),
		);
	}
}
