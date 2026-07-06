abstract final class WebNotificationService {
	static bool get supported => false;

	static String get permission => "denied";

	static bool get isGranted => false;

	static Future<String> requestPermission() async => "denied";

	static void show({
		required String title,
		required String body,
		String? tag,
	}) {}
}
