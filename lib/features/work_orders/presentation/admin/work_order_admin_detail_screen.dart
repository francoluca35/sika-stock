import "dart:typed_data";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:share_plus/share_plus.dart";

import "../../../../core/files/save_bytes_file.dart";
import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../application/work_orders_providers.dart";
import "../../domain/work_order.dart";
import "../widgets/work_order_pdf_panel.dart";

class WorkOrderAdminDetailScreen extends ConsumerStatefulWidget {
	const WorkOrderAdminDetailScreen({super.key, required this.workOrderId});

	final String workOrderId;

	@override
	ConsumerState<WorkOrderAdminDetailScreen> createState() =>
			_WorkOrderAdminDetailScreenState();
}

class _WorkOrderAdminDetailScreenState extends ConsumerState<WorkOrderAdminDetailScreen> {
	Uint8List? _originalPdf;
	bool _loadingPdf = false;
	final Set<String> _downloadingPaths = {};

	@override
	void initState() {
		super.initState();
		_loadOriginal();
	}

	Future<void> _loadOriginal() async {
		final wo = await ref.read(workOrdersRepositoryProvider).fetchWorkOrderById(widget.workOrderId);
		if (wo == null || !mounted) return;
		setState(() => _loadingPdf = true);
		try {
			final bytes = await ref.read(workOrdersRepositoryProvider).downloadStorageBytes(
						wo.originalPdfPath,
					);
			if (mounted) setState(() => _originalPdf = bytes);
		} finally {
			if (mounted) setState(() => _loadingPdf = false);
		}
	}

	Future<Uint8List> _fetchPdfBytes(String path) {
		return ref.read(workOrdersRepositoryProvider).downloadStorageBytes(path);
	}

	String _completedPdfFilename(WorkOrder wo, String? assigneeName) {
		final ot = wo.otNumber?.trim();
		final base = (ot != null && ot.isNotEmpty) ? "OT-$ot" : "OT-${wo.id.substring(0, 8)}";
		final tech = (assigneeName ?? "").trim();
		if (tech.isEmpty) return "$base-completada.pdf";
		final safeTech = tech.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
		return "$base-$safeTech-completada.pdf";
	}

	Future<void> _sharePdf(String path, String name) async {
		try {
			final bytes = await _fetchPdfBytes(path);
			await Share.shareXFiles(
				[
					XFile.fromData(
						bytes,
						name: name,
						mimeType: "application/pdf",
					),
				],
				text: "OT completada — Sika Stock",
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo compartir: $e")),
			);
		}
	}

	Future<void> _downloadPdf(String path, String name) async {
		if (_downloadingPaths.contains(path)) return;
		setState(() => _downloadingPaths.add(path));
		try {
			final bytes = await _fetchPdfBytes(path);
			final saved = await saveBytesToDevice(
				bytes: bytes,
				filename: name,
				mimeType: "application/pdf",
			);
			if (!mounted) return;
			final msg = kIsWeb
					? "Descarga iniciada: $name"
					: saved != null
							? "PDF guardado en Descargas"
							: "PDF descargado";
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo descargar: $e")),
			);
		} finally {
			if (mounted) setState(() => _downloadingPaths.remove(path));
		}
	}

	@override
	Widget build(BuildContext context) {
		final woAsync = ref.watch(workOrderDetailProvider(widget.workOrderId));
		final assignAsync = ref.watch(workOrderAssignmentsProvider(widget.workOrderId));

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: const Text("Detalle OT", style: TextStyle(fontWeight: FontWeight.bold)),
				actions: [
					IconButton(
						icon: const Icon(Icons.refresh),
						onPressed: () {
							ref.invalidate(workOrderDetailProvider(widget.workOrderId));
							ref.invalidate(workOrderAssignmentsProvider(widget.workOrderId));
							_loadOriginal();
						},
					),
				],
			),
			body: woAsync.when(
				data: (wo) {
					if (wo == null) {
						return const Center(child: Text("OT no encontrada"));
					}
					return ListView(
						padding: const EdgeInsets.all(16),
						children: [
							Text(
								wo.title,
								style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
							),
							if (wo.otNumber != null && wo.otNumber!.isNotEmpty)
								Text("Nº ${wo.otNumber}", style: TextStyle(color: Colors.grey.shade700)),
							Text(
								"Creada: ${ArgentinaDateTime.formatDateTime(wo.createdAt)}",
								style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
							),
							if (wo.pdfMetadata.hasAnyData) ...[
								const SizedBox(height: 12),
								Text(
									"Planta: ${wo.pdfMetadata.plant.isEmpty ? "—" : wo.pdfMetadata.plant}",
									style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
								),
							],
							const SizedBox(height: 12),
							const Text("PDF original", style: TextStyle(fontWeight: FontWeight.bold)),
							const SizedBox(height: 8),
							if (_loadingPdf)
								const SizedBox(
									height: 120,
									child: Center(child: CircularProgressIndicator()),
								)
							else if (_originalPdf != null)
								WorkOrderPdfPanel(pdfBytes: _originalPdf!, height: 280),
							const SizedBox(height: 20),
							const Text("Asignaciones", style: TextStyle(fontWeight: FontWeight.bold)),
							const SizedBox(height: 8),
							assignAsync.when(
								data: (assignments) {
									if (assignments.isEmpty) {
										return const Text("Sin asignaciones.");
									}
									return Column(
										children: assignments.map((a) {
											final done = a.status == "completed";
											final resp = a.response;
											final pdfPath = resp?.completedPdfPath;
											return Card(
												margin: const EdgeInsets.only(bottom: 10),
												child: Padding(
													padding: const EdgeInsets.all(12),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text(
																a.assigneeName ?? a.userId,
																style: const TextStyle(fontWeight: FontWeight.w800),
															),
															Text(
																done ? "Completada" : "Pendiente",
																style: TextStyle(
																	color: done
																			? Colors.green.shade800
																			: Colors.orange.shade900,
																	fontWeight: FontWeight.w600,
																),
															),
															if (done && resp != null) ...[
																if (resp.startedAt != null)
																	Text(
																		"Inicio: ${ArgentinaDateTime.formatDateOnly(resp.startedAt!)}",
																		style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
																	),
																if (resp.finishedAt != null)
																	Text(
																		"Finalización: ${ArgentinaDateTime.formatDateOnly(resp.finishedAt!)}",
																		style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
																	),
																if (resp.formData.tasksNews.isNotEmpty) ...[
																	const SizedBox(height: 6),
																	Text(
																		"Novedades: ${resp.formData.tasksNews}",
																		style: const TextStyle(fontSize: 12),
																		maxLines: 3,
																		overflow: TextOverflow.ellipsis,
																	),
																],
																if (pdfPath != null) ...[
																	const SizedBox(height: 8),
																	Builder(
																		builder: (context) {
																			final fileName = _completedPdfFilename(
																				wo,
																				a.assigneeName,
																			);
																			final downloading = _downloadingPaths.contains(pdfPath);
																			return Row(
																				children: [
																					Expanded(
																						child: OutlinedButton.icon(
																							onPressed: downloading
																									? null
																									: () => _downloadPdf(pdfPath, fileName),
																							icon: downloading
																									? const SizedBox(
																											width: 18,
																											height: 18,
																											child: CircularProgressIndicator(strokeWidth: 2),
																										)
																									: const Icon(Icons.download, size: 18),
																							label: const Text("Descargar"),
																						),
																					),
																					const SizedBox(width: 8),
																					Expanded(
																						child: OutlinedButton.icon(
																							onPressed: downloading
																									? null
																									: () => _sharePdf(pdfPath, fileName),
																							icon: const Icon(Icons.share, size: 18),
																							label: const Text("Compartir"),
																						),
																					),
																				],
																			);
																		},
																	),
																],
															],
														],
													),
												),
											);
										}).toList(),
									);
								},
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text("Error: $e"),
							),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text("Error: $e")),
			),
		);
	}
}
