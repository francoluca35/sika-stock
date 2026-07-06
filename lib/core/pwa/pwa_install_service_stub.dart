abstract final class PwaInstallService {
	static bool get supported => false;

	static bool get canInstall => false;

	static bool get isStandalone => false;

	static bool get isIosSafari => false;

	static Future<String> promptInstall() async => "unavailable";

	static void listenInstallAvailable(void Function() onAvailable) {}

	static void listenInstalled(void Function() onInstalled) {}
}
