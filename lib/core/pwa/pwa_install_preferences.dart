import "package:shared_preferences/shared_preferences.dart";

abstract final class PwaInstallPreferences {
	static const _dismissedKey = "pwa_install_banner_dismissed";

	static Future<bool> isBannerDismissed() async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getBool(_dismissedKey) ?? false;
	}

	static Future<void> setBannerDismissed(bool dismissed) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setBool(_dismissedKey, dismissed);
	}
}
