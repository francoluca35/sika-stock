import "package:shared_preferences/shared_preferences.dart";

/// Preferencias locales para avisos de escritorio / navegador.
abstract final class DesktopNotificationPreferences {
	static const _prefix = "desktop_notif_";

	static String _key(String userId, String suffix) => "$_prefix${userId}_$suffix";

	static Future<bool> wasPrompted(String userId) async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getBool(_key(userId, "prompted")) ?? false;
	}

	static Future<void> setPrompted(String userId) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setBool(_key(userId, "prompted"), true);
	}

	static Future<bool> isEnabled(String userId) async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getBool(_key(userId, "enabled")) ?? false;
	}

	static Future<void> setEnabled(String userId, bool enabled) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setBool(_key(userId, "enabled"), enabled);
	}
}
