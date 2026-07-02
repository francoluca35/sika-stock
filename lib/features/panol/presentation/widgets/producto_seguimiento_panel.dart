import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../../compras/application/compras_stock_repository_provider.dart";
import "../../../compras/presentation/widgets/compras_screen_metrics.dart";
import "../../../orders/application/mantenimiento_notificaciones_provider.dart";
import "../../application/panol_seguimiento_compras_provider.dart";

/// Estado agregado del producto en el flujo compra → entrega.
enum SeguimientoCompraEstado {
	/// Aún no se emitió / registró la compra.
	pendienteCompra,

	/// Ya comprado (OC / proveedor); falta entrega o está en tránsito.
	comprado,

	/// Entregado en planta / recepción cerrada.
	entregado,
}

/// Un paso en el historial con marca de tiempo.
class SeguimientoEvento {
	const SeguimientoEvento({
		required this.titulo,
		required this.cuando,
	});

	final String titulo;
	final DateTime cuando;
}

/// Ítem mostrado en el listado de seguimiento.
class ProductoSeguimiento {
	const ProductoSeguimiento({
		required this.id,
		required this.producto,
		required this.estado,
		required this.trayecto,
		this.maintenanceOrderId,
		this.workflowStatus,
		this.referenciaPedido,
	});

	final String id;
	final String producto;
	final String? referenciaPedido;
	final String? maintenanceOrderId;
	final String? workflowStatus;
	final SeguimientoCompraEstado estado;

	/// Eventos ordenados cronológicamente (más antiguo primero).
	final List<SeguimientoEvento> trayecto;

	bool get puedeAvisarListoRetiro =>
			(workflowStatus == "panol_requested_compras" ||
					workflowStatus == "compras_oc_notified" ||
					workflowStatus == "compras_purchase_done") &&
			maintenanceOrderId != null &&
			maintenanceOrderId!.isNotEmpty;
}

Color _colorEstado(SeguimientoCompraEstado e) {
	switch (e) {
		case SeguimientoCompraEstado.pendienteCompra:
			return AppTokens.statusPending;
		case SeguimientoCompraEstado.comprado:
			return AppTokens.statusWarn;
		case SeguimientoCompraEstado.entregado:
			return AppTokens.statusOk;
	}
}

String _etiquetaEstado(SeguimientoCompraEstado e) {
	switch (e) {
		case SeguimientoCompraEstado.pendienteCompra:
			return "Pedido a compras";
		case SeguimientoCompraEstado.comprado:
			return "Pedido a compras";
		case SeguimientoCompraEstado.entregado:
			return "Listo para retirar";
	}
}

String _fmtFechaHora(DateTime d) => ArgentinaDateTime.formatDateTime(d);

/// Listado dinámico: color por estado; al tocar un ítem se abre el detalle del trayecto.
class ProductoSeguimientoPanel extends ConsumerWidget {
	const ProductoSeguimientoPanel({
		super.key,
		required this.items,
	});

	final List<ProductoSeguimiento> items;

	static Future<void> avisarListoParaRetiro(
		WidgetRef ref,
		ProductoSeguimiento item,
	) async {
		final oid = item.maintenanceOrderId;
		if (oid == null || !item.puedeAvisarListoRetiro) return;
		await ref.read(comprasStockRepositoryProvider).panolNotifyReadyForPickup(oid);
		ref.invalidate(panolSeguimientoComprasProvider);
		ref.invalidate(mantenimientoNotificacionesProvider);
	}

	static void mostrarTrayecto(BuildContext context, ProductoSeguimiento p) {
		final ordenados = [...p.trayecto]..sort((a, b) => a.cuando.compareTo(b.cuando));
		final colorEstado = _colorEstado(p.estado);

		showDialog<void>(
			context: context,
			builder: (ctx) {
				final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
				return AlertDialog(
					titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
					contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
					actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
					title: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text(
								p.producto,
								style: const TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 18,
									color: Colors.black87,
								),
							),
							if (p.referenciaPedido != null &&
									p.referenciaPedido!.trim().isNotEmpty) ...[
								const SizedBox(height: 6),
								Text(
									p.referenciaPedido!.trim(),
									style: TextStyle(
										fontSize: 13,
										color: Colors.grey.shade700,
										fontWeight: FontWeight.w600,
									),
								),
							],
							const SizedBox(height: 10),
							Row(
								children: [
									Container(
										width: 10,
										height: 10,
										decoration: BoxDecoration(
											color: colorEstado,
											shape: BoxShape.circle,
										),
									),
									const SizedBox(width: 8),
									Text(
										_etiquetaEstado(p.estado),
										style: TextStyle(
											fontWeight: FontWeight.w700,
											fontSize: 14,
											color: colorEstado,
										),
									),
								],
							),
							const SizedBox(height: 4),
							Text(
								"Cambios de estado (fecha y hora)",
								style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
							),
						],
					),
					content: SizedBox(
						width: math.min(420.0, MediaQuery.sizeOf(ctx).width - 64),
						child: ConstrainedBox(
							constraints: BoxConstraints(maxHeight: maxH),
							child: SingleChildScrollView(
								child: Padding(
									padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
									child: _TrayectoTimeline(
										eventos: ordenados,
										colorEstado: colorEstado,
									),
								),
							),
						),
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text("Cerrar"),
						),
					],
				);
			},
		);
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		if (items.isEmpty) {
			return Center(
				child: Text(
					"No hay productos en seguimiento.",
					style: TextStyle(color: Colors.grey.shade600),
				),
			);
		}

		final pad = ComprasScreenMetrics.horizontalPadding(context);
		return ListView.separated(
			padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 16),
			itemCount: items.length,
			separatorBuilder: (_, __) => const SizedBox(height: 10),
			itemBuilder: (ctx, i) {
				final p = items[i];
				final c = _colorEstado(p.estado);
				return _ProductoSeguimientoCard(
					item: p,
					colorEstado: c,
					onTap: () => mostrarTrayecto(context, p),
					onAvisarListoRetiro: p.puedeAvisarListoRetiro
							? () async {
									try {
										await avisarListoParaRetiro(ref, p);
										if (!context.mounted) return;
										ScaffoldMessenger.of(context).showSnackBar(
											SnackBar(
												content: Text(
													"Aviso enviado: ${p.producto} listo para retirar.",
												),
											),
										);
									} catch (e) {
										if (!context.mounted) return;
										ScaffoldMessenger.of(context).showSnackBar(
											SnackBar(
												content: Text("No se pudo avisar: $e"),
											),
										);
									}
								}
							: null,
				);
			},
		);
	}
}

class _ProductoSeguimientoCard extends StatelessWidget {
	const _ProductoSeguimientoCard({
		required this.item,
		required this.colorEstado,
		required this.onTap,
		this.onAvisarListoRetiro,
	});

	final ProductoSeguimiento item;
	final Color colorEstado;
	final VoidCallback onTap;
	final Future<void> Function()? onAvisarListoRetiro;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: Colors.transparent,
			child: Ink(
				decoration: BoxDecoration(
					color: AppTokens.whiteSurface,
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					border: Border.all(color: AppTokens.greyBorder),
					boxShadow: [
						BoxShadow(
							color: Colors.black.withValues(alpha: 0.04),
							blurRadius: 6,
							offset: const Offset(0, 2),
						),
					],
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						InkWell(
							onTap: onTap,
							borderRadius: BorderRadius.vertical(
								top: const Radius.circular(AppTokens.radiusMd),
								bottom: Radius.circular(
									onAvisarListoRetiro != null ? 0 : AppTokens.radiusMd,
								),
							),
							child: IntrinsicHeight(
								child: Row(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Container(
											width: 6,
											decoration: BoxDecoration(
												color: colorEstado,
												borderRadius: BorderRadius.horizontal(
													left: const Radius.circular(AppTokens.radiusMd - 1),
													right: onAvisarListoRetiro != null
															? Radius.zero
															: const Radius.circular(0),
												),
											),
										),
										Expanded(
											child: Padding(
												padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
												child: Row(
													children: [
														Expanded(
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	Text(
																		item.producto,
																		style: const TextStyle(
																			fontWeight: FontWeight.w700,
																			fontSize: 16,
																			color: Colors.black87,
																		),
																	),
																	const SizedBox(height: 6),
																	Wrap(
																		spacing: 8,
																		runSpacing: 4,
																		crossAxisAlignment: WrapCrossAlignment.center,
																		children: [
																			Container(
																				padding: const EdgeInsets.symmetric(
																					horizontal: 8,
																					vertical: 3,
																				),
																				decoration: BoxDecoration(
																					color: colorEstado.withValues(
																						alpha: 0.18,
																					),
																					borderRadius: BorderRadius.circular(6),
																				),
																				child: Text(
																					_etiquetaEstado(item.estado),
																					style: TextStyle(
																						fontSize: 11,
																						fontWeight: FontWeight.w800,
																						color: colorEstado,
																					),
																				),
																			),
																			if (item.referenciaPedido != null &&
																					item.referenciaPedido!
																							.trim()
																							.isNotEmpty)
																				Text(
																					item.referenciaPedido!.trim(),
																					style: TextStyle(
																						fontSize: 12,
																						color: Colors.grey.shade700,
																					),
																				),
																		],
																	),
																],
															),
														),
														Icon(
															Icons.chevron_right,
															color: Colors.grey.shade600,
														),
													],
												),
											),
										),
									],
								),
							),
						),
						if (onAvisarListoRetiro != null)
							Padding(
								padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
								child: FilledButton.icon(
									onPressed: onAvisarListoRetiro,
									icon: const Icon(Icons.inventory_2, size: 20),
									label: const Text("Avisar listo para retirar"),
									style: FilledButton.styleFrom(
										backgroundColor: AppTokens.statusOk,
										foregroundColor: Colors.white,
										padding: const EdgeInsets.symmetric(vertical: 12),
									),
								),
							),
					],
				),
			),
		);
	}
}

class _TrayectoTimeline extends StatelessWidget {
	const _TrayectoTimeline({
		required this.eventos,
		required this.colorEstado,
	});

	final List<SeguimientoEvento> eventos;
	final Color colorEstado;

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				for (var i = 0; i < eventos.length; i++) ...[
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Padding(
								padding: const EdgeInsets.only(top: 2),
								child: Column(
									children: [
										Container(
											width: 12,
											height: 12,
											decoration: BoxDecoration(
												color: i == eventos.length - 1
														? colorEstado
														: Colors.grey.shade500,
												shape: BoxShape.circle,
												border: Border.all(color: Colors.white, width: 2),
												boxShadow: [
													BoxShadow(
														color: Colors.black.withValues(alpha: 0.08),
														blurRadius: 2,
													),
												],
											),
										),
										if (i < eventos.length - 1)
											Container(
												width: 2,
												height: 44,
												margin: const EdgeInsets.only(top: 4),
												color: Colors.grey.shade300,
											),
									],
								),
							),
							const SizedBox(width: 12),
							Expanded(
								child: Padding(
									padding: const EdgeInsets.only(bottom: 14),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												eventos[i].titulo,
												style: const TextStyle(
													fontWeight: FontWeight.w700,
													fontSize: 14,
													color: Colors.black87,
													height: 1.25,
												),
											),
											const SizedBox(height: 4),
											Text(
												_fmtFechaHora(eventos[i].cuando),
												style: TextStyle(
													fontSize: 13,
													color: Colors.grey.shade700,
													fontFeatures: const [FontFeature.tabularFigures()],
												),
											),
										],
									),
								),
							),
						],
					),
				],
			],
		);
	}
}
