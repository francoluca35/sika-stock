import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Entrada desde la derecha y salida hacia la derecha al hacer **atrás** (estilo navegación móvil).
CustomTransitionPage<void> slideHorizontalRoutePage({
	required LocalKey pageKey,
	required Widget child,
}) {
	return CustomTransitionPage<void>(
		key: pageKey,
		child: child,
		transitionDuration: const Duration(milliseconds: 320),
		reverseTransitionDuration: const Duration(milliseconds: 280),
		transitionsBuilder: (context, animation, secondaryAnimation, child) {
			final curved = CurvedAnimation(
				parent: animation,
				curve: Curves.easeOutCubic,
				reverseCurve: Curves.easeInCubic,
			);
			return SlideTransition(
				position: Tween<Offset>(
					begin: const Offset(1.0, 0.0),
					end: Offset.zero,
				).animate(curved),
				child: child,
			);
		},
	);
}
