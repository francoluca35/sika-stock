import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../application/supervisor_stock_catalog_provider.dart";
import "../../data/stock_excel_file_picker.dart";
import "../../data/stock_excel_importer.dart";

/// Modal Pañol: elegir `.xlsx` y confirmar con **CARGAR LISTA**.
Future<void> showStockExcelImportDialog(BuildContext context, WidgetRef ref) {
	return showDialog<void>(
		context: context,
		barrierDismissible: false,
		builder: (ctx) => _StockExcelImportDialog(
			onImport: (rows) =>
					ref.read(stockCatalogRepositoryProvider).insertBatch(rows),
			onSuccess: () => ref.invalidate(supervisorStockCatalogProvider),
		),
	);
}

class _StockExcelImportDialog extends StatefulWidget {
	const _StockExcelImportDialog({
		required this.onImport,
		required this.onSuccess,
	});

	final Future<int> Function(List<Map<String, dynamic>> rows) onImport;
	final VoidCallback onSuccess;

	@override
	State<_StockExcelImportDialog> createState() => _StockExcelImportDialogState();
}

class _StockExcelImportDialogState extends State<_StockExcelImportDialog> {
	String? _nombreArchivo;
	StockExcelParseResult? _parsed;
	bool _eligiendo = false;
	bool _importando = false;
	String? _errorSeleccion;

	Future<void> _elegirArchivo() async {
		setState(() {
			_eligiendo = true;
			_errorSeleccion = null;
		});
		try {
			final picked = await pickStockExcelFile();
			if (!mounted) return;
			if (picked == null) {
				setState(() => _eligiendo = false);
				return;
			}
			final parsed = StockExcelImporter.parseBytes(picked.bytes);
			setState(() {
				_eligiendo = false;
				_nombreArchivo = picked.name;
				_parsed = parsed;
				_errorSeleccion = !parsed.tieneFilasValidas && parsed.errores.isNotEmpty
						? parsed.errores.first
						: null;
			});
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_eligiendo = false;
				_errorSeleccion = "Error al abrir el archivo: $e";
				_nombreArchivo = null;
				_parsed = null;
			});
		}
	}

	Future<void> _cargarLista() async {
		final parsed = _parsed;
		if (parsed == null || !parsed.tieneFilasValidas || _importando) return;

		setState(() => _importando = true);
		try {
			final maps = parsed.rows.map((r) => r.toInsertMap()).toList();
			final importados = await widget.onImport(maps);
			if (!mounted) return;
			widget.onSuccess();
			Navigator.of(context).pop();

			final resumen = StringBuffer("Se importaron $importados producto(s).");

			await showDialog<void>(
				context: context,
				builder: (ctx) => AlertDialog(
					title: const Text("Importación completada"),
					content: SingleChildScrollView(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(resumen.toString()),
							],
						),
					),
					actions: [
						FilledButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text("Listo"),
						),
					],
				),
			);
		} catch (e) {
			if (!mounted) return;
			setState(() => _importando = false);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo importar: $e")),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final parsed = _parsed;
		final filasValidas = parsed?.rows.length ?? 0;
		final puedeCargar = parsed != null && parsed.tieneFilasValidas && !_importando;

		return AlertDialog(
			title: const Row(
				children: [
					Icon(Icons.upload_file_outlined, color: Colors.black87),
					SizedBox(width: 10),
					Expanded(
						child: Text(
							"Cargar Excel",
							style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
						),
					),
				],
			),
			content: SizedBox(
				width: 420,
				child: SingleChildScrollView(
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								"Seleccioná un archivo .xlsx. Se importan todas las filas con datos; "
								"los campos vacíos se guardan en blanco o en 0.",
								style: TextStyle(
									fontSize: 13,
									height: 1.35,
									color: Colors.grey.shade800,
								),
							),
							const SizedBox(height: 16),
							OutlinedButton.icon(
								onPressed: (_eligiendo || _importando) ? null : _elegirArchivo,
								icon: _eligiendo
										? const SizedBox(
												width: 18,
												height: 18,
												child: CircularProgressIndicator(strokeWidth: 2),
											)
										: const Icon(Icons.folder_open_outlined),
								label: Text(
									_nombreArchivo == null
											? "SELECCIONAR ARCHIVO"
											: "CAMBIAR ARCHIVO",
								),
								style: OutlinedButton.styleFrom(
									padding: const EdgeInsets.symmetric(vertical: 14),
									foregroundColor: Colors.black87,
									side: const BorderSide(color: Colors.black54, width: 1.2),
								),
							),
							if (_nombreArchivo != null) ...[
								const SizedBox(height: 12),
								DecoratedBox(
									decoration: BoxDecoration(
										color: AppTokens.surfaceMuted,
										borderRadius: BorderRadius.circular(AppTokens.radiusMd),
										border: Border.all(color: AppTokens.greyBorder),
									),
									child: Padding(
										padding: const EdgeInsets.all(12),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													_nombreArchivo!,
													style: const TextStyle(
														fontWeight: FontWeight.w700,
														fontSize: 13,
													),
												),
												if (parsed != null && parsed.tieneFilasValidas) ...[
													const SizedBox(height: 6),
													Text(
														"$filasValidas producto${filasValidas == 1 ? "" : "s"} listos para importar.",
														style: TextStyle(
															fontSize: 13,
															color: Colors.green.shade800,
															fontWeight: FontWeight.w600,
														),
													),
												],
											],
										),
									),
								),
							],
							if (_errorSeleccion != null) ...[
								const SizedBox(height: 10),
								Text(
									_errorSeleccion!,
									style: TextStyle(
										fontSize: 12,
										color: Colors.red.shade800,
										height: 1.3,
									),
								),
							],
							const SizedBox(height: 20),
							SizedBox(
								height: 48,
								child: FilledButton.icon(
									onPressed: puedeCargar ? _cargarLista : null,
									icon: _importando
											? const SizedBox(
													width: 18,
													height: 18,
													child: CircularProgressIndicator(
														strokeWidth: 2,
														color: Colors.white,
													),
												)
											: const Icon(Icons.playlist_add_check_outlined),
									label: Text(
										_importando ? "IMPORTANDO…" : "CARGAR LISTA",
										style: const TextStyle(fontWeight: FontWeight.bold),
									),
									style: FilledButton.styleFrom(
										backgroundColor: AppTokens.redAction,
										foregroundColor: Colors.white,
									),
								),
							),
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: _importando ? null : () => Navigator.of(context).pop(),
					child: const Text("Cancelar"),
				),
			],
		);
	}
}
