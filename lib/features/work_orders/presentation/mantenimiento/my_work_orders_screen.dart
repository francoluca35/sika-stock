import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../application/work_orders_providers.dart";
import "../widgets/work_order_ot_lookup_screen.dart";
import "work_order_complete_screen.dart";

class MyWorkOrdersScreen extends ConsumerWidget {
	const MyWorkOrdersScreen({super.key});

	Future<void> _openScanner(BuildContext context, WidgetRef ref) async {
		final refreshed = await Navigator.of(context).push<bool>(
			MaterialPageRoute(
				builder: (_) => const WorkOrderOtLookupScreen(
					mode: WorkOrderOtLookupMode.maintenance,
				),
			),
		);
		if (refreshed == true) {
			ref.invalidate(myWorkOrderAssignmentsProvider);
		}
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(myWorkOrderAssignmentsProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: const Text(
					"MIS ÓRDENES DE TRABAJO",
					style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
				),
				actions: [
					IconButton(
						tooltip: "Escanear código OT",
						icon: const Icon(Icons.qr_code_scanner),
						onPressed: () => _openScanner(context, ref),
					),
					IconButton(
						icon: const Icon(Icons.refresh),
						onPressed: () => ref.invalidate(myWorkOrderAssignmentsProvider),
					),
				],
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () => _openScanner(context, ref),
				backgroundColor: AppTokens.redAction,
				icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
				label: const Text("Escanear OT", style: TextStyle(color: Colors.white)),
			),
			body: async.when(
				data: (list) {
					if (list.isEmpty) {
						return const Center(
							child: Padding(
								padding: EdgeInsets.all(24),
								child: Text(
									"No tenés órdenes de trabajo asignadas.",
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
							final a = list[i];
							final wo = a.workOrder;
							final title = wo?.title ?? "OT";
							final pending = a.isPending;
							return Material(
								color: Colors.white,
								borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								child: ListTile(
									title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
									subtitle: Text(
										"${wo?.otNumber != null ? 'OT ${wo!.otNumber} · ' : ''}"
										"${ArgentinaDateTime.formatDateTime(a.assignedAt)} · "
										"${pending ? 'Pendiente' : 'Enviada'}",
									),
									trailing: Icon(
										pending ? Icons.edit_document : Icons.check_circle,
										color: pending ? AppTokens.redAction : AppTokens.statusOk,
									),
									onTap: pending && wo != null
											? () async {
													final done = await Navigator.of(context).push<bool>(
														MaterialPageRoute(
															builder: (_) => WorkOrderCompleteScreen(assignmentId: a.id),
														),
													);
													if (done == true) {
														ref.invalidate(myWorkOrderAssignmentsProvider);
													}
												}
											: null,
								),
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
