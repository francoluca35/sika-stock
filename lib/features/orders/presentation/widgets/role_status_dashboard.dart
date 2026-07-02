import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/application/auth_providers.dart";
import "../../../auth/domain/app_role.dart";
import "../../../panol/application/panol_forwarded_orders_provider.dart";
import "../../../supervisor/application/maintenance_orders_provider.dart";
import "../../../supervisor/application/maintenance_stock_similarity.dart";
import "../../../supervisor/domain/maintenance_order.dart";
import "../../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../application/mis_pedidos_mantenimiento_provider.dart";
import "../../application/order_navigation_target_provider.dart";
import "maintenance_order_seguimiento_sheet.dart";
import "maintenance_order_timeline.dart";

/// Tablero de estado en vivo según el rol del usuario.
class RoleStatusDashboard extends ConsumerWidget {
	const RoleStatusDashboard({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final role = ref.watch(currentProfileProvider).value?.rol;
		return switch (role) {
			AppRole.mantenimiento => const _MantenimientoDashboard(),
			AppRole.panol => const _PanolDashboard(),
			AppRole.supervisor => const _SupervisorDashboard(),
			AppRole.admin || AppRole.superadmin => const _SupervisorDashboard(),
			_ => const SizedBox.shrink(),
		};
	}
}

class _DashboardShell extends StatelessWidget {
	const _DashboardShell({
		required this.title,
		required this.children,
	});

	final String title;
	final List<Widget> children;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.whiteSurface,
			borderRadius: BorderRadius.circular(AppTokens.radiusMd),
			elevation: 0,
			child: Container(
				decoration: BoxDecoration(
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					border: Border.all(color: Colors.black87, width: 1.1),
				),
				padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							children: [
								const Icon(Icons.dashboard_outlined, size: 20),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										title,
										style: const TextStyle(
											fontWeight: FontWeight.w800,
											fontSize: 14,
											color: Colors.black87,
										),
									),
								),
							],
						),
						const SizedBox(height: 12),
						...children,
					],
				),
			),
		);
	}
}

class _MantenimientoDashboard extends ConsumerWidget {
	const _MantenimientoDashboard();

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(misPedidosMantenimientoProvider);
		return async.when(
			data: (list) {
				final activos = list
						.where(
							(o) =>
									o.workflowStatus !=
											MaintenanceWorkflowStatus.completed &&
									o.workflowStatus != MaintenanceWorkflowStatus.cancelled,
						)
						.take(5)
						.toList();
				if (activos.isEmpty) return const SizedBox.shrink();

				return _DashboardShell(
					title: "Tus pedidos en curso",
					children: [
						for (final o in activos) ...[
							_OrderDashboardTile(
								order: o,
								onTap: () => showMaintenanceOrderSeguimientoSheet(
									context,
									o,
									ref: ref,
								),
							),
							if (o != activos.last) const SizedBox(height: 10),
						],
						if (list.length > activos.length) ...[
							const SizedBox(height: 8),
							TextButton(
								onPressed: () => context.push("/pedidos/mis-pedidos"),
								child: const Text("Ver todos mis pedidos"),
							),
						],
					],
				);
			},
			loading: () => const _DashboardLoading(),
			error: (_, __) => const SizedBox.shrink(),
		);
	}
}

class _PanolDashboard extends ConsumerWidget {
	const _PanolDashboard();

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(panolForwardedOrdersProvider);
		return async.when(
			data: (list) {
				var consultas = 0;
				var listosRetiro = 0;
				for (final o in list) {
					switch (o.workflowStatus) {
						case MaintenanceWorkflowStatus.forwardedToPanol:
						case MaintenanceWorkflowStatus.panolRequestedCompras:
						case MaintenanceWorkflowStatus.comprasOcNotified:
						case MaintenanceWorkflowStatus.comprasPurchaseDone:
							consultas++;
							break;
						case MaintenanceWorkflowStatus.supervisorStockOk:
						case MaintenanceWorkflowStatus.comprasArrivedNotified:
							listosRetiro++;
							break;
						default:
							break;
					}
				}

				if (consultas == 0 && listosRetiro == 0) {
					return const SizedBox.shrink();
				}

				return _DashboardShell(
					title: "Cola de pañol",
					children: [
						Row(
							children: [
								Expanded(
									child: _CounterCard(
										label: "Consultas",
										count: consultas,
										color: Colors.orange.shade800,
										icon: Icons.help_outline,
										onTap: () => context.push("/panol/pedidos"),
									),
								),
								const SizedBox(width: 10),
								Expanded(
									child: _CounterCard(
										label: "Listos retiro",
										count: listosRetiro,
										color: const Color(0xFF2E7D32),
										icon: Icons.inventory_outlined,
										onTap: () => context.push("/panol/pedidos"),
									),
								),
							],
						),
						if (listosRetiro > 0) ...[
							const SizedBox(height: 12),
							Text(
								"Últimos listos para retirar",
								style: TextStyle(
									fontSize: 12,
									fontWeight: FontWeight.w700,
									color: Colors.grey.shade700,
								),
							),
							const SizedBox(height: 8),
							...list
									.where(
										(o) =>
												o.workflowStatus ==
														MaintenanceWorkflowStatus
																.supervisorStockOk ||
												o.workflowStatus ==
														MaintenanceWorkflowStatus
																.comprasArrivedNotified,
									)
									.take(3)
									.map(
										(o) => Padding(
											padding: const EdgeInsets.only(bottom: 8),
											child: _CompactOrderRow(
												order: o,
												onTap: () {
													ref
															.read(
																orderNavigationTargetProvider
																		.notifier,
															)
															.setTarget(o.id);
													context.push("/panol/pedidos");
												},
											),
										),
									),
						],
					],
				);
			},
			loading: () => const _DashboardLoading(),
			error: (_, __) => const SizedBox.shrink(),
		);
	}
}

class _SupervisorDashboard extends ConsumerWidget {
	const _SupervisorDashboard();

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final ordersAsync = ref.watch(maintenanceOrdersProvider);
		final stockAsync = ref.watch(supervisorStockCatalogProvider);

		return ordersAsync.when(
			data: (orders) {
				final pendientes = orders
						.where(
							(o) =>
									o.workflowStatus ==
									MaintenanceWorkflowStatus.pendingSupervisor,
						)
						.toList();
				if (pendientes.isEmpty) return const SizedBox.shrink();

				final catalog = stockAsync.value ?? const [];
				var sinCoincidencia = 0;
				for (final o in pendientes) {
					final analisis = analizarStockPedido(o, catalog);
					if (analisis.match == null) sinCoincidencia++;
				}

				return _DashboardShell(
					title: "Pendientes de revisión",
					children: [
						Row(
							children: [
								Expanded(
									child: _CounterCard(
										label: "Por revisar",
										count: pendientes.length,
										color: AppTokens.yellowHeader,
										fg: Colors.black87,
										icon: Icons.pending_actions_outlined,
										onTap: () =>
												context.push("/supervisor/pedidos-mantenimiento"),
									),
								),
								const SizedBox(width: 10),
								Expanded(
									child: _CounterCard(
										label: "Sin coincidencia",
										count: sinCoincidencia,
										color: Colors.orange.shade800,
										icon: Icons.search_off_outlined,
										onTap: () =>
												context.push("/supervisor/pedidos-mantenimiento"),
									),
								),
							],
						),
						const SizedBox(height: 12),
						...pendientes.take(3).map(
							(o) => Padding(
								padding: const EdgeInsets.only(bottom: 8),
								child: _CompactOrderRow(
									order: o,
									onTap: () {
										ref
												.read(orderNavigationTargetProvider.notifier)
												.setTarget(o.id);
										context.push("/supervisor/pedidos-mantenimiento");
									},
								),
							),
						),
					],
				);
			},
			loading: () => const _DashboardLoading(),
			error: (_, __) => const SizedBox.shrink(),
		);
	}
}

class _CounterCard extends StatelessWidget {
	const _CounterCard({
		required this.label,
		required this.count,
		required this.color,
		required this.icon,
		required this.onTap,
		this.fg = Colors.white,
	});

	final String label;
	final int count;
	final Color color;
	final Color fg;
	final IconData icon;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: color,
			borderRadius: BorderRadius.circular(10),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(10),
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Icon(icon, color: fg, size: 22),
							const SizedBox(height: 8),
							Text(
								"$count",
								style: TextStyle(
									fontWeight: FontWeight.w900,
									fontSize: 24,
									color: fg,
									height: 1,
								),
							),
							const SizedBox(height: 4),
							Text(
								label,
								style: TextStyle(
									fontWeight: FontWeight.w700,
									fontSize: 12,
									color: fg.withValues(alpha: 0.95),
								),
							),
						],
					),
				),
			),
		);
	}
}

class _OrderDashboardTile extends StatelessWidget {
	const _OrderDashboardTile({
		required this.order,
		required this.onTap,
	});

	final MaintenanceOrder order;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.surfacePage,
			borderRadius: BorderRadius.circular(8),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(8),
				child: Padding(
					padding: const EdgeInsets.all(10),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											order.numeroOrden,
											style: const TextStyle(
												fontWeight: FontWeight.w800,
												fontSize: 13,
											),
										),
									),
									const Icon(Icons.chevron_right, size: 20),
								],
							),
							const SizedBox(height: 4),
							Text(
								order.producto,
								maxLines: 2,
								overflow: TextOverflow.ellipsis,
								style: TextStyle(
									fontSize: 12,
									color: Colors.grey.shade800,
								),
							),
							const SizedBox(height: 8),
							MaintenanceOrderProgressBar(status: order.workflowStatus),
						],
					),
				),
			),
		);
	}
}

class _CompactOrderRow extends StatelessWidget {
	const _CompactOrderRow({
		required this.order,
		required this.onTap,
	});

	final MaintenanceOrder order;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.surfacePage,
			borderRadius: BorderRadius.circular(8),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(8),
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
					child: Row(
						children: [
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											order.numeroOrden,
											style: const TextStyle(
												fontWeight: FontWeight.w700,
												fontSize: 12.5,
											),
										),
										Text(
											order.producto,
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
											style: TextStyle(
												fontSize: 11.5,
												color: Colors.grey.shade700,
											),
										),
									],
								),
							),
							const Icon(Icons.chevron_right, size: 18),
						],
					),
				),
			),
		);
	}
}

class _DashboardLoading extends StatelessWidget {
	const _DashboardLoading();

	@override
	Widget build(BuildContext context) {
		return const Padding(
			padding: EdgeInsets.symmetric(vertical: 8),
			child: Center(
				child: SizedBox(
					width: 22,
					height: 22,
					child: CircularProgressIndicator(strokeWidth: 2),
				),
			),
		);
	}
}
