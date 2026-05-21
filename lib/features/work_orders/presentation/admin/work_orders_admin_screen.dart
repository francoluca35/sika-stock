import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../application/work_orders_providers.dart";
import "../../domain/work_order.dart";
import "work_order_admin_detail_screen.dart";
import "work_order_new_screen.dart";

class WorkOrdersAdminScreen extends ConsumerWidget {
	const WorkOrdersAdminScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(adminWorkOrdersProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: const Text(
					"ÓRDENES DE TRABAJO",
					style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
				),
				actions: [
					IconButton(
						icon: const Icon(Icons.refresh),
						onPressed: () => ref.invalidate(adminWorkOrdersProvider),
					),
				],
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () async {
					final created = await Navigator.of(context).push<bool>(
						MaterialPageRoute(builder: (_) => const WorkOrderNewScreen()),
					);
					if (created == true) {
						ref.invalidate(adminWorkOrdersProvider);
					}
				},
				backgroundColor: AppTokens.redAction,
				icon: const Icon(Icons.upload_file, color: Colors.white),
				label: const Text("Subir OT", style: TextStyle(color: Colors.white)),
			),
			body: async.when(
				data: (list) {
					if (list.isEmpty) {
						return const Center(
							child: Padding(
								padding: EdgeInsets.all(24),
								child: Text(
									"Subí un PDF de orden de trabajo y asignalo a mantenimiento.",
									textAlign: TextAlign.center,
								),
							),
						);
					}
					return ListView.separated(
						padding: const EdgeInsets.all(16),
						itemCount: list.length,
						separatorBuilder: (_, __) => const SizedBox(height: 10),
						itemBuilder: (context, i) {
							final wo = list[i];
							return _WorkOrderAdminTile(
								order: wo,
								onTap: () {
									Navigator.of(context).push(
										MaterialPageRoute(
											builder: (_) => WorkOrderAdminDetailScreen(workOrderId: wo.id),
										),
									);
								},
							);
						},
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text("Error: $e")),
			),
		);
	}
}

class _WorkOrderAdminTile extends StatelessWidget {
	const _WorkOrderAdminTile({required this.order, required this.onTap});

	final WorkOrder order;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		final statusColor = order.isCompleted ? AppTokens.statusOk : AppTokens.yellowHeader;
		return Material(
			color: Colors.white,
			borderRadius: BorderRadius.circular(AppTokens.radiusMd),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				child: Padding(
					padding: const EdgeInsets.all(14),
					child: Row(
						children: [
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											order.title,
											style: const TextStyle(
												fontWeight: FontWeight.w800,
												fontSize: 15,
											),
										),
										if (order.otNumber != null && order.otNumber!.isNotEmpty)
											Text(
												"OT ${order.otNumber}",
												style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
											),
										Text(
											ArgentinaDateTime.formatDateTime(order.createdAt),
											style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
										),
									],
								),
							),
							Container(
								padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
								decoration: BoxDecoration(
									color: statusColor,
									borderRadius: BorderRadius.circular(20),
								),
								child: Text(
									order.isCompleted ? "COMPLETADA" : "EN CURSO",
									style: TextStyle(
										fontSize: 11,
										fontWeight: FontWeight.bold,
										color: order.isCompleted ? Colors.white : Colors.black87,
									),
								),
							),
							const Icon(Icons.chevron_right),
						],
					),
				),
			),
		);
	}
}
