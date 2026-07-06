(function () {
	let deferredPrompt = null;

	window.sikaPwaIsStandalone = function () {
		return (
			window.matchMedia("(display-mode: standalone)").matches ||
			window.navigator.standalone === true
		);
	};

	window.sikaPwaIsIosSafari = function () {
		const ua = window.navigator.userAgent;
		const isIOS =
			/iPad|iPhone|iPod/.test(ua) ||
			(navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
		const isSafari = /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS/.test(ua);
		return isIOS && isSafari && !window.sikaPwaIsStandalone();
	};

	window.sikaPwaCanInstall = function () {
		return !!deferredPrompt;
	};

	window.sikaPwaInstall = async function () {
		if (!deferredPrompt) return "unavailable";
		deferredPrompt.prompt();
		const choice = await deferredPrompt.userChoice;
		const outcome = choice.outcome;
		deferredPrompt = null;
		return outcome;
	};

	window.addEventListener("beforeinstallprompt", function (e) {
		e.preventDefault();
		deferredPrompt = e;
		window.dispatchEvent(new Event("sika-pwa-install-available"));
	});

	window.addEventListener("appinstalled", function () {
		deferredPrompt = null;
		window.dispatchEvent(new Event("sika-pwa-installed"));
	});
})();
