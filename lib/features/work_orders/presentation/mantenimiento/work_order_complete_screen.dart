import "dart:typed_data";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/application/auth_providers.dart";
import "../../application/work_orders_providers.dart";
import "../../domain/work_order_pdf_metadata.dart";
import "../widgets/work_order_pdf_open.dart";
import "../widgets/work_order_pdf_viewer_page.dart";
import "../widgets/work_order_readonly_fields.dart";
import "../widgets/work_order_signature_field.dart";

class WorkOrderCompleteScreen extends ConsumerStatefulWidget {
	const WorkOrderCompleteScreen({super.key, required this.assignmentId});

	final String assignmentId;

	@override
	ConsumerState<WorkOrderCompleteScreen> createState() => _WorkOrderCompleteScreenState();
}

class _WorkOrderCompleteScreenState extends ConsumerState<WorkOrderCompleteScreen> {
	final _workDescCtrl = TextEditingController();
	final _tasksCtrl = TextEditingController();
	final _obsCtrl = TextEditingController();
	Uint8List? _pdfBytes;
	WorkOrderPdfMetadata _metadata = const WorkOrderPdfMetadata();
	String _receiverName = "";
	Uint8List? _signaturePng;
	final List<Uint8List> _attachments = [];
	bool _loading = true;
	bool _sending = false;

	bool get _isMobile => !kIsWeb;

	@override
	void dispose() {
		_workDescCtrl.dispose();
		_tasksCtrl.dispose();
		_obsCtrl.dispose();
		super.dispose();
	}

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		try {
			final a = await ref.read(workOrdersRepositoryProvider).fetchAssignmentById(widget.assignmentId);
			final wo = a?.workOrder;
			if (wo != null) {
				_metadata = wo.pdfMetadata;
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
				if (mounted) setState(() => _pdfBytes = bytes);
			}
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Future<void> _openPdfOnPhone() async {
		if (_pdfBytes == null) return;
		final ok = await openPdfExternally(
			_pdfBytes!,
			otNumber: _metadata.orderNumber,
		);
		if (!mounted) return;
		if (!ok) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text("No hay visor PDF. Probá «Ver en pantalla»."),
				),
			);
		}
	}

	void _openPdfInApp() {
		if (_pdfBytes == null) return;
		openWorkOrderPdfViewer(
			context,
			_pdfBytes!,
			otNumber: _metadata.orderNumber,
		);
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

	Future<void> _submit() async {
		if (_signaturePng == null || _signaturePng!.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Confirmá tu firma antes de enviar.")),
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

		setState(() => _sending = true);
		try {
			await ref.read(workOrdersRepositoryProvider).submitAssignmentResponse(
						assignment: assignment,
						assigneeName: name,
						formData: WorkOrderFormData(
							workDescription: _workDescCtrl.text,
							tasksNews: _tasksCtrl.text,
							observations: _obsCtrl.text,
						),
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

	Widget _pdfButtons() {
		if (_pdfBytes == null) {
			return const Text("PDF no disponible.", style: TextStyle(color: Colors.grey));
		}
		if (_isMobile) {
			return Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					FilledButton.icon(
						onPressed: _openPdfOnPhone,
						icon: const Icon(Icons.picture_as_pdf),
						label: const Text(
							"ABRIR PDF EN EL CELULAR",
							style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
						),
						style: FilledButton.styleFrom(
							backgroundColor: AppTokens.redAction,
							foregroundColor: Colors.white,
							padding: const EdgeInsets.symmetric(vertical: 16),
						),
					),
					const SizedBox(height: 8),
					Text(
						"Se abre con el visor del teléfono (zoom, pantalla completa). Podés volver a entrar cuando quieras.",
						style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
					),
					const SizedBox(height: 8),
					OutlinedButton.icon(
						onPressed: _openPdfInApp,
						icon: const Icon(Icons.fullscreen),
						label: const Text("Ver en pantalla (alternativa)"),
						style: OutlinedButton.styleFrom(
							padding: const EdgeInsets.symmetric(vertical: 12),
						),
					),
				],
			);
		}
		return OutlinedButton.icon(
			onPressed: _openPdfInApp,
			icon: const Icon(Icons.picture_as_pdf_outlined),
			label: const Text("VER PDF"),
			style: OutlinedButton.styleFrom(
				padding: const EdgeInsets.symmetric(vertical: 14),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) {
			return const Scaffold(body: Center(child: CircularProgressIndicator()));
		}

		final form = ListView(
			padding: EdgeInsets.fromLTRB(16, 16, 16, _isMobile ? 100 : 24),
			children: [
				_pdfButtons(),
				const SizedBox(height: 16),
				WorkOrderReadonlyFields(
					metadata: _metadata,
					receiverName: _receiverName,
				),
				const SizedBox(height: 16),
				const Text("Descripción del trabajo", style: TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 6),
				TextField(
					controller: _workDescCtrl,
					maxLines: 4,
					enabled: !_sending,
					decoration: const InputDecoration(
						hintText: "Trabajo realizado…",
						border: OutlineInputBorder(),
						alignLabelWithHint: true,
					),
				),
				const SizedBox(height: 16),
				const Text("Novedades y tareas", style: TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 6),
				TextField(
					controller: _tasksCtrl,
					maxLines: 4,
					enabled: !_sending,
					decoration: const InputDecoration(
						hintText: "Novedades, tareas pendientes, repuestos…",
						border: OutlineInputBorder(),
						alignLabelWithHint: true,
					),
				),
				const SizedBox(height: 16),
				const Text("Observaciones", style: TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 6),
				TextField(
					controller: _obsCtrl,
					maxLines: 3,
					enabled: !_sending,
					decoration: const InputDecoration(
						border: OutlineInputBorder(),
						alignLabelWithHint: true,
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
					style: OutlinedButton.styleFrom(
						padding: const EdgeInsets.symmetric(vertical: 14),
					),
				),
				if (_attachments.isNotEmpty)
					Padding(
						padding: const EdgeInsets.only(top: 8),
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
													padding: EdgeInsets.zero,
													minimumSize: const Size(28, 28),
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
				const SizedBox(height: 20),
				const Text("Firma", style: TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 8),
				WorkOrderSignatureField(
					onChanged: (b) => setState(() => _signaturePng = b),
				),
				if (!_isMobile) ...[
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
			],
		);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: const Text("Completar OT", style: TextStyle(fontWeight: FontWeight.bold)),
				actions: [
					if (!_isMobile)
						TextButton.icon(
							onPressed: _sending ? null : _submit,
							icon: _sending
									? const SizedBox(
											width: 18,
											height: 18,
											child: CircularProgressIndicator(strokeWidth: 2),
										)
									: const Icon(Icons.send, color: AppTokens.redAction),
							label: Text(
								"ENVIAR",
								style: TextStyle(
									fontWeight: FontWeight.bold,
									color: _sending ? Colors.grey : AppTokens.redAction,
								),
							),
						),
				],
			),
			body: _isMobile
					? Column(
							children: [
								Expanded(child: form),
								Material(
									elevation: 8,
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
														padding: const EdgeInsets.symmetric(vertical: 16),
													),
													child: _sending
															? const SizedBox(
																	height: 22,
																	width: 22,
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
																	),
																),
												),
											),
										),
									),
								),
							],
						)
					: form,
		);
	}
}
