import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "go_router_refresh.dart";
import "../../features/admin/presentation/create_users_screen.dart";
import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/presentation/login_screen.dart";
import "../../features/home/presentation/home_screen.dart";

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
				path: "/admin/nuevos-usuarios",
				builder: (context, state) => const CreateUsersScreen(),
			),
		],
	);
});
