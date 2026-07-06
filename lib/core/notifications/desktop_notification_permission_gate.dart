import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../features/auth/application/auth_session_provider.dart";
import "../theme/app_tokens.dart";
import "desktop_notification_preferences.dart";
import "web_notification_service.dart";

/// Pregunta una sola vez si el usuario quiere avisos de escritorio.
class DesktopNotificationPermissionGate extends ConsumerStatefulWidget {
	const DesktopNotificationPermissionGate({super.key});

	@override
	ConsumerState<DesktopNotificationPermissionGate> createState() =>
			_DesktopNotificationPermissionGateState();
}

class _DesktopNotificationPermissionGateState
		extends ConsumerState<DesktopNotificationPermissionGate> {
	bool _checking = false;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
	}

	Future<void> _maybePrompt() async {
		if (_checking || !mounted) return;
		final session = ref.read(authSessionProvider);
		if (session == null) return;

		final userId = session.user.id;
		final prompted = await DesktopNotificationPreferences.wasPrompted(userId);
		if (prompted || !mounted) return;

		_checking = true;
		await Future<void>.delayed(const Duration(milliseconds: 600));
		if (!mounted) return;

		await showDialog<void>(
			context: context,
			barrierDismissible: false,
			builder: (ctx) => AlertDialog(
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
				title: Row(
					children: [
						Container(
							padding: const EdgeInsets.all(8),
							decoration: BoxDecoration(
								color: AppTokens.yellowHeader,
								borderRadius: BorderRadius.circular(10),
								border: Border.all(color: Colors.black87),
							),
							child: const Icon(Icons.notifications_outlined, size: 24),
						),
						const SizedBox(width: 12),
						const Expanded(
							child: Text(
								"¿Recibir avisos?",
								style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
							),
						),
					],
				),
				content: const Text(
					"¿Querés recibir notificaciones de la app cuando alguien "
					"haga un pedido o haya novedades en el flujo?\n\n"
					"Verás un aviso en la esquina de la pantalla y, si el "
					"navegador lo permite, también en el escritorio.",
					style: TextStyle(height: 1.35, fontSize: 14),
				),
				actions: [
					TextButton(
						onPressed: () async {
							await DesktopNotificationPreferences.setPrompted(userId);
							await DesktopNotificationPreferences.setEnabled(userId, false);
							if (ctx.mounted) Navigator.pop(ctx);
						},
						child: const Text("No, gracias"),
					),
					FilledButton(
						style: FilledButton.styleFrom(
							backgroundColor: AppTokens.blackNav,
							foregroundColor: Colors.white,
						),
						onPressed: () async {
							await DesktopNotificationPreferences.setPrompted(userId);
							await DesktopNotificationPreferences.setEnabled(userId, true);
							if (WebNotificationService.supported) {
								await WebNotificationService.requestPermission();
							}
							if (ctx.mounted) Navigator.pop(ctx);
						},
						child: const Text("Sí, activar avisos"),
					),
				],
			),
		);

		_checking = false;
	}

	@override
	Widget build(BuildContext context) {
		ref.listen(authSessionProvider, (prev, next) {
			if (prev?.user.id != next?.user.id) {
				WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
			}
		});
		return const SizedBox.shrink();
	}
}
