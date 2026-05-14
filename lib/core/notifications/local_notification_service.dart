import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";

/// Notificaciones en la barra del sistema (Android / iOS). En web no hace nada.
abstract final class LocalNotificationService {
	static final FlutterLocalNotificationsPlugin _plugin =
			FlutterLocalNotificationsPlugin();

	static bool _initialized = false;

	static bool get supported =>
			!kIsWeb && (Platform.isAndroid || Platform.isIOS);

	static Future<void> initialize() async {
		if (!supported || _initialized) return;

		const android = AndroidInitializationSettings("@mipmap/ic_launcher");
		const ios = DarwinInitializationSettings(
			requestAlertPermission: true,
			requestBadgePermission: true,
			requestSoundPermission: true,
		);
		await _plugin.initialize(
			settings: const InitializationSettings(
				android: android,
				iOS: ios,
			),
		);

		if (Platform.isAndroid) {
			final androidPlugin = _plugin
					.resolvePlatformSpecificImplementation<
							AndroidFlutterLocalNotificationsPlugin>();
			await androidPlugin?.createNotificationChannel(
				const AndroidNotificationChannel(
					"sika_stock_alerts",
					"Alertas Sika Stock",
					description: "Pedidos y avisos del flujo de mantenimiento y compras",
					importance: Importance.high,
				),
			);
			await androidPlugin?.requestNotificationsPermission();
		}

		if (Platform.isIOS) {
			await _plugin
					.resolvePlatformSpecificImplementation<
							IOSFlutterLocalNotificationsPlugin>()
					?.requestPermissions(alert: true, badge: true, sound: true);
		}

		_initialized = true;
	}

	static int _idForKey(String key) => key.hashCode & 0x7fffffff;

	static Future<void> showAlert({
		required String idKey,
		required String title,
		required String body,
	}) async {
		if (!supported || !_initialized) return;
		await _plugin.show(
			id: _idForKey(idKey),
			title: title,
			body: body,
			notificationDetails: const NotificationDetails(
				android: AndroidNotificationDetails(
					"sika_stock_alerts",
					"Alertas Sika Stock",
					channelDescription:
							"Pedidos y avisos del flujo de mantenimiento y compras",
					importance: Importance.high,
					priority: Priority.high,
					icon: "@mipmap/ic_launcher",
				),
				iOS: DarwinNotificationDetails(
					presentAlert: true,
					presentBadge: true,
					presentSound: true,
				),
			),
		);
	}
}
