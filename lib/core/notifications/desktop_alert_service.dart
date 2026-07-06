import "package:flutter/foundation.dart";

import "desktop_notification_preferences.dart";
import "desktop_toast_controller.dart";
import "local_notification_service.dart";
import "web_notification_service.dart";

/// Muestra avisos en escritorio (toast in-app + navegador / móvil si aplica).
abstract final class DesktopAlertService {
	static Future<void> show({
		required String userId,
		required DesktopToastNotifier toastNotifier,
		required String idKey,
		required String title,
		required String message,
		String? subtitle,
		String? actionLabel,
		VoidCallback? onAction,
	}) async {
		final enabled = await DesktopNotificationPreferences.isEnabled(userId);
		if (!enabled) return;

		toastNotifier.show(
			idKey: idKey,
			title: title,
			message: message,
			subtitle: subtitle,
			actionLabel: actionLabel,
			onAction: onAction,
		);

		final body = subtitle == null || subtitle.trim().isEmpty
				? message
				: "$message\n$subtitle";

		if (WebNotificationService.supported) {
			WebNotificationService.show(
				title: title,
				body: body,
				tag: idKey,
			);
		}

		await LocalNotificationService.showAlert(
			idKey: idKey,
			title: title,
			body: body,
		);
	}
}

/// Nombre legible del solicitante (sin sufijos de rol).
String formatSolicitanteNombre(String solicitante) {
	final limpio = solicitante
			.replaceFirst(
				RegExp(r"\s*·\s*Mantenimiento\s*$", caseSensitive: false),
				"",
			)
			.trim();
	return limpio.isEmpty ? "Un usuario" : limpio;
}
