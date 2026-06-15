import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../application/work_orders_providers.dart";
import "../admin/work_order_admin_detail_screen.dart";
import "../mantenimiento/work_order_complete_screen.dart";

enum WorkOrderOtLookupMode { maintenance, admin }

/// Escanea código de barras del PDF o ingresa Nº OT manualmente.
class WorkOrderOtLookupScreen extends ConsumerStatefulWidget {
	const WorkOrderOtLookupScreen({
		super.key,
		this.mode = WorkOrderOtLookupMode.maintenance,
	});

	final WorkOrderOtLookupMode mode;

	@override
	ConsumerState<WorkOrderOtLookupScreen> createState() => _WorkOrderOtLookupScreenState();
}

class _WorkOrderOtLookupScreenState extends ConsumerState<WorkOrderOtLookupScreen> {
	final _manualCtrl = TextEditingController();
	final MobileScannerController _scannerCtrl = MobileScannerController(
		detectionSpeed: DetectionSpeed.noDuplicates,
		facing: CameraFacing.back,
	);
	bool _busy = false;
	String? _lastHandled;

	@override
	void dispose() {
		_manualCtrl.dispose();
		_scannerCtrl.dispose();
		super.dispose();
	}

	Future<void> _lookup(String raw) async {
		final code = raw.trim();
		if (code.isEmpty || _busy) return;
		if (_lastHandled == code) return;

		setState(() {
			_busy = true;
			_lastHandled = code;
		});

		try {
			final repo = ref.read(workOrdersRepositoryProvider);
			if (widget.mode == WorkOrderOtLookupMode.maintenance) {
				final lookup = await repo.lookupMyAssignmentByOtNumber(code);
				if (!mounted) return;
				if (lookup.alreadyCompleted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(
							content: Text("Esta OT ya fue enviada. No podés editarla."),
						),
					);
					return;
				}
				final assignment = lookup.assignment;
				if (assignment == null) {
					_showNotFound(code);
					return;
				}
				final done = await Navigator.of(context).push<bool>(
					MaterialPageRoute(
						builder: (_) => WorkOrderCompleteScreen(assignmentId: assignment.id),
					),
				);
				if (!mounted) return;
				if (done == true) Navigator.of(context).pop(true);
			} else {
				final wo = await repo.findWorkOrderByOtNumber(code);
				if (!mounted) return;
				if (wo == null) {
					_showNotFound(code);
					return;
				}
				await Navigator.of(context).push(
					MaterialPageRoute(
						builder: (_) => WorkOrderAdminDetailScreen(workOrderId: wo.id),
					),
				);
			}
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("Error al buscar: $e")),
			);
		} finally {
			if (mounted) setState(() => _busy = false);
			Future<void>.delayed(const Duration(seconds: 2), () {
				if (mounted) setState(() => _lastHandled = null);
			});
		}
	}

	void _showNotFound(String code) {
		final hint = widget.mode == WorkOrderOtLookupMode.maintenance
				? "No tenés una OT pendiente con ese número."
				: "No hay ninguna OT registrada con ese número.";
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text("$hint\nCódigo: $code"),
				duration: const Duration(seconds: 4),
			),
		);
	}

	void _onDetect(BarcodeCapture capture) {
		if (_busy) return;
		for (final b in capture.barcodes) {
			final v = b.rawValue;
			if (v != null && v.trim().isNotEmpty) {
				_lookup(v);
				return;
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final isMaintenance = widget.mode == WorkOrderOtLookupMode.maintenance;
		final title = isMaintenance ? "Escanear OT" : "Buscar OT";

		return Scaffold(
			backgroundColor: Colors.black,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
			),
			body: Column(
				children: [
					if (!kIsWeb)
						Expanded(
							flex: 3,
							child: Stack(
								alignment: Alignment.center,
								children: [
									MobileScanner(
										controller: _scannerCtrl,
										onDetect: _onDetect,
									),
									IgnorePointer(
										child: Container(
											width: 260,
											height: 120,
											decoration: BoxDecoration(
												border: Border.all(color: AppTokens.redAction, width: 2.5),
												borderRadius: BorderRadius.circular(12),
											),
										),
									),
									if (_busy)
										const ColoredBox(
											color: Color(0x88000000),
											child: Center(child: CircularProgressIndicator()),
										),
								],
							),
						),
					Expanded(
						flex: kIsWeb ? 1 : 2,
						child: Container(
							width: double.infinity,
							color: AppTokens.surfacePage,
							padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									Text(
										kIsWeb
												? "Ingresá el número de OT"
												: "O ingresá el número manualmente",
										style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
									),
									const SizedBox(height: 6),
									Text(
										"Ej.: 4783 o código de barras 02004783",
										style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
									),
									const SizedBox(height: 14),
									TextField(
										controller: _manualCtrl,
										keyboardType: TextInputType.number,
										textInputAction: TextInputAction.search,
										enabled: !_busy,
										decoration: InputDecoration(
											hintText: "Nº OT",
											filled: true,
											fillColor: Colors.white,
											prefixIcon: const Icon(Icons.numbers, color: AppTokens.redAction),
											border: OutlineInputBorder(
												borderRadius: BorderRadius.circular(AppTokens.radiusMd),
											),
										),
										onSubmitted: _lookup,
									),
									const SizedBox(height: 12),
									FilledButton.icon(
										onPressed: _busy ? null : () => _lookup(_manualCtrl.text),
										icon: _busy
												? const SizedBox(
														width: 18,
														height: 18,
														child: CircularProgressIndicator(
															strokeWidth: 2,
															color: Colors.white,
														),
													)
												: const Icon(Icons.search),
										label: Text(isMaintenance ? "ABRIR OT" : "BUSCAR OT"),
										style: FilledButton.styleFrom(
											backgroundColor: AppTokens.redAction,
											padding: const EdgeInsets.symmetric(vertical: 16),
										),
									),
									if (!kIsWeb) ...[
										const SizedBox(height: 10),
										OutlinedButton.icon(
											onPressed: _busy
													? null
													: () async {
															await _scannerCtrl.toggleTorch();
															setState(() {});
														},
											icon: Icon(
												_scannerCtrl.torchEnabled ? Icons.flash_on : Icons.flash_off,
											),
											label: const Text("Linterna"),
										),
									],
								],
							),
						),
					),
				],
			),
		);
	}
}
