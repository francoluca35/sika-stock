import "dart:js_interop";

import "package:web/web.dart";

@JS("sikaPwaCanInstall")
external bool _sikaPwaCanInstall();

@JS("sikaPwaInstall")
external JSPromise<JSString> _sikaPwaInstall();

@JS("sikaPwaIsStandalone")
external bool _sikaPwaIsStandalone();

@JS("sikaPwaIsIosSafari")
external bool _sikaPwaIsIosSafari();

abstract final class PwaInstallService {
	static bool get supported => true;

	static bool get canInstall => _sikaPwaCanInstall();

	static bool get isStandalone => _sikaPwaIsStandalone();

	static bool get isIosSafari => _sikaPwaIsIosSafari();

	static Future<String> promptInstall() async {
		final result = await _sikaPwaInstall().toDart;
		return result.toDart;
	}

	static void listenInstallAvailable(void Function() onAvailable) {
		void handler(Event _) => onAvailable();
		window.addEventListener("sika-pwa-install-available", handler.toJS);
	}

	static void listenInstalled(void Function() onInstalled) {
		void handler(Event _) => onInstalled();
		window.addEventListener("sika-pwa-installed", handler.toJS);
	}
}
