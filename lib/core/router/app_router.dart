import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "go_router_refresh.dart";
import "slide_transition_page.dart";
import "../../features/compras/presentation/compras_historial_compras_screen.dart";
import "../../features/compras/presentation/compras_historial_pedidos_screen.dart";
import "../../features/admin/presentation/create_users_screen.dart";
import "../../features/admin/presentation/users_list_screen.dart";
import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/presentation/login_screen.dart";
import "../../features/home/presentation/home_screen.dart";
import "../../features/orders/presentation/my_maintenance_orders_screen.dart";
import "../../features/orders/presentation/place_order_screen.dart";
import "../../features/panol/presentation/panol_pedidos_screen.dart";
import "../../features/panol/presentation/widgets/seguimiento_access_gate.dart";
import "../../features/panol/presentation/panol_stock_hub_screen.dart";
import "../../features/panol/presentation/panol_stock_screen.dart";
import "../../features/stock/presentation/add_stock_screen.dart";
import "../../features/stock/presentation/categories_screen.dart";
import "../../features/stock/presentation/stock_home_screen.dart";
import "../../features/supervisor/presentation/supervisor_maintenance_history_screen.dart";
import "../../features/supervisor/presentation/supervisor_maintenance_orders_screen.dart";
import "../../features/supervisor/presentation/supervisor_stock_screen.dart";

final goRouterProvider = Provider<GoRouter>((ref) {
	final client = ref.watch(supabaseClientProvider);
	final refresh = GoRouterRefreshStream(client.auth.onAuthStateChange);
	ref.onDispose(refresh.dispose);

	return GoRouter(
		initialLocation: "/login",
		refreshListenable: refresh,
		redirect: (BuildContext context, GoRouterState state) {
			final session = client.auth.currentSession;
			final path = state.matchedLocation;
			final authRoute = path == "/login";

			if (session == null && !authRoute) {
				return "/login";
			}
			if (session != null && authRoute) {
				return "/home";
			}
			return null;
		},
		routes: <RouteBase>[
			GoRoute(
				path: "/login",
				builder: (context, state) => const LoginScreen(),
			),
			GoRoute(
				path: "/home",
				builder: (context, state) => const HomeScreen(),
			),
			GoRoute(
				path: "/compras/historial-pedidos",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const ComprasHistorialPedidosScreen(),
				),
			),
			GoRoute(
				path: "/compras/historial-compras",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const ComprasHistorialComprasScreen(),
				),
			),
			GoRoute(
				path: "/admin/nuevos-usuarios",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const CreateUsersScreen(),
				),
			),
			GoRoute(
				path: "/admin/usuarios",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const UsersListScreen(),
				),
			),
			GoRoute(
				path: "/pedidos/nuevo",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const PlaceOrderScreen(),
				),
			),
			GoRoute(
				path: "/pedidos/mis-pedidos",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const MyMaintenanceOrdersScreen(),
				),
			),
			GoRoute(
				path: "/stock",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const StockHomeScreen(),
				),
			),
			GoRoute(
				path: "/panol/stock",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const PanolStockScreen(),
				),
			),
			GoRoute(
				path: "/panol/stock-opciones",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const PanolStockHubScreen(),
				),
			),
			GoRoute(
				path: "/panol/pedidos",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const PanolPedidosScreen(),
				),
			),
			GoRoute(
				path: "/panol/seguimiento",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const SeguimientoAccessGate(),
				),
			),
			GoRoute(
				path: "/panol/categorias",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const CategoriesScreen(fallbackLocation: "/home"),
				),
			),
			GoRoute(
				path: "/supervisor/stock",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const SupervisorStockScreen(),
				),
			),
			GoRoute(
				path: "/supervisor/pedidos-mantenimiento",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const SupervisorMaintenanceOrdersScreen(),
				),
			),
			GoRoute(
				path: "/supervisor/historial-pedidos",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const SupervisorMaintenanceHistoryScreen(),
				),
			),
			GoRoute(
				path: "/stock/agregar",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const AddStockScreen(),
				),
			),
			GoRoute(
				path: "/stock/categorias",
				pageBuilder: (context, state) => slideHorizontalRoutePage(
					pageKey: state.pageKey,
					child: const CategoriesScreen(),
				),
			),
		],
	);
});
