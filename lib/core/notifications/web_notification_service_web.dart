import "dart:js_interop";

import "package:web/web.dart";

/// Notificaciones nativas del navegador (Web Notifications API).
abstract final class WebNotificationService {
	static bool get supported => true;

	static String get permission => Notification.permission;

	static bool get isGranted => permission == "granted";

	static Future<String> requestPermission() async {
		final result = await Notification.requestPermission().toDart;
		return result.toDart;
	}

	static void show({
		required String title,
		required String body,
		String? tag,
	}) {
		if (!isGranted) return;
		Notification(
			title,
			NotificationOptions(
				body: body,
				tag: tag ?? title,
				icon: "icons/Icon-192.png",
			),
		);
	}
}
