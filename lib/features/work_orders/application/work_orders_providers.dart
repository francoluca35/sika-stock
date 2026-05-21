import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../data/work_orders_repository.dart";
import "../domain/work_order.dart";

final workOrdersRepositoryProvider = Provider<WorkOrdersRepository>(
	(ref) => WorkOrdersRepository(ref.watch(supabaseClientProvider)),
);

final maintenanceStaffProfilesProvider = FutureProvider((ref) async {
	return ref.read(workOrdersRepositoryProvider).fetchMaintenanceProfiles();
});

final adminWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
	return ref.read(workOrdersRepositoryProvider).fetchAdminWorkOrders();
});

final myWorkOrderAssignmentsProvider = FutureProvider<List<WorkOrderAssignment>>((ref) async {
	return ref.read(workOrdersRepositoryProvider).fetchMyAssignments();
});

final workOrderAssignmentsProvider =
		FutureProvider.family<List<WorkOrderAssignment>, String>((ref, workOrderId) async {
	return ref.read(workOrdersRepositoryProvider).fetchAssignmentsForWorkOrder(workOrderId);
});

final workOrderDetailProvider = FutureProvider.family<WorkOrder?, String>((ref, id) async {
	return ref.read(workOrdersRepositoryProvider).fetchWorkOrderById(id);
});
