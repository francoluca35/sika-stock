import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../theme/app_tokens.dart";
import "pwa_install_preferences.dart";
import "pwa_install_service.dart";

/// Banner superior para instalar la PWA (Chrome/Edge) o instrucciones en iPhone.
class PwaInstallBanner extends StatefulWidget {
	const PwaInstallBanner({super.key});

	@override
	State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
	bool _loading = true;
	bool _dismissed = false;
	bool _canInstall = false;
	bool _iosHint = false;
	bool _installing = false;

	@override
	void initState() {
		super.initState();
		_refresh();
		if (kIsWeb && PwaInstallService.supported) {
			PwaInstallService.listenInstallAvailable(_refresh);
			PwaInstallService.listenInstalled(() {
				if (mounted) setState(() => _canInstall = false);
			});
		}
	}

	Future<void> _refresh() async {
		if (!kIsWeb || !PwaInstallService.supported) {
			if (mounted) setState(() => _loading = false);
			return;
		}
		if (PwaInstallService.isStandalone) {
			if (mounted) {
				setState(() {
					_loading = false;
					_canInstall = false;
					_iosHint = false;
				});
			}
			return;
		}

		final dismissed = await PwaInstallPreferences.isBannerDismissed();
		if (!mounted) return;
		setState(() {
			_dismissed = dismissed;
			_canInstall = PwaInstallService.canInstall;
			_iosHint = PwaInstallService.isIosSafari;
			_loading = false;
		});
	}

	bool get _shouldShow =>
			!_loading &&
			!_dismissed &&
			!PwaInstallService.isStandalone &&
			(_canInstall || _iosHint);

	Future<void> _dismiss() async {
		await PwaInstallPreferences.setBannerDismissed(true);
		if (!mounted) return;
		setState(() => _dismissed = true);
	}

	Future<void> _install() async {
		if (_iosHint) {
			if (!mounted) return;
			await showDialog<void>(
				context: context,
				builder: (ctx) => AlertDialog(
					title: const Text("Agregar a inicio"),
					content: const Text(
						"En iPhone o iPad:\n\n"
						"1. Tocá el botón Compartir (cuadrado con flecha).\n"
						"2. Elegí «Agregar a inicio».\n"
						"3. Confirmá con «Agregar».\n\n"
						"La app quedará como un ícono en tu pantalla.",
					),
					actions: [
						FilledButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text("Entendido"),
						),
					],
				),
			);
			return;
		}

		setState(() => _installing = true);
		try {
			final outcome = await PwaInstallService.promptInstall();
			if (!mounted) return;
			if (outcome == "accepted") {
				setState(() => _canInstall = false);
			} else if (outcome == "unavailable") {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							"La instalación no está disponible en este navegador. "
							"Usá Chrome o Edge.",
						),
					),
				);
			}
		} finally {
			if (mounted) setState(() => _installing = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		if (!_shouldShow) return const SizedBox.shrink();

		final top = MediaQuery.paddingOf(context).top;
		final title = _iosHint ? "Usá Sika Stock como app" : "Instalá Sika Stock";
		final subtitle = _iosHint
				? "Agregala a la pantalla de inicio para abrirla como una app."
				: "Acceso rápido desde el escritorio o el inicio del celular.";

		return Positioned(
			top: top + 8,
			left: 12,
			right: 12,
			child: Material(
				elevation: 6,
				shadowColor: Colors.black38,
				borderRadius: BorderRadius.circular(12),
				color: AppTokens.yellowHeader,
				child: Container(
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(12),
						border: Border.all(color: Colors.black87, width: 1.2),
					),
					padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Container(
								padding: const EdgeInsets.all(8),
								decoration: BoxDecoration(
									color: AppTokens.whiteSurface,
									borderRadius: BorderRadius.circular(10),
									border: Border.all(color: Colors.black87),
								),
								child: const Icon(Icons.install_mobile, size: 24),
							),
							const SizedBox(width: 12),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											title,
											style: const TextStyle(
												fontWeight: FontWeight.w800,
												fontSize: 14,
												color: Colors.black87,
											),
										),
										const SizedBox(height: 4),
										Text(
											subtitle,
											style: TextStyle(
												fontSize: 12.5,
												height: 1.3,
												color: Colors.grey.shade900,
											),
										),
										const SizedBox(height: 10),
										Wrap(
											spacing: 8,
											runSpacing: 6,
											children: [
												FilledButton(
													onPressed: _installing ? null : _install,
													style: FilledButton.styleFrom(
														backgroundColor: AppTokens.blackNav,
														foregroundColor: Colors.white,
														padding: const EdgeInsets.symmetric(
															horizontal: 14,
															vertical: 8,
														),
														minimumSize: Size.zero,
														tapTargetSize: MaterialTapTargetSize.shrinkWrap,
													),
													child: _installing
															? const SizedBox(
																	width: 18,
																	height: 18,
																	child: CircularProgressIndicator(
																		strokeWidth: 2,
																		color: Colors.white,
																	),
																)
															: Text(
																	_iosHint ? "Cómo hacerlo" : "Instalar",
																	style: const TextStyle(
																		fontWeight: FontWeight.w700,
																		fontSize: 13,
																	),
																),
												),
												TextButton(
													onPressed: _dismiss,
													child: const Text(
														"Ahora no",
														style: TextStyle(
															fontWeight: FontWeight.w600,
															color: Colors.black87,
														),
													),
												),
											],
										),
									],
								),
							),
							IconButton(
								tooltip: "Cerrar",
								padding: EdgeInsets.zero,
								constraints: const BoxConstraints(
									minWidth: 32,
									minHeight: 32,
								),
								icon: const Icon(Icons.close, size: 20),
								onPressed: _dismiss,
							),
						],
					),
				),
			),
		);
	}
}

/// Botón reutilizable en Configuración.
class PwaInstallSettingsButton extends StatefulWidget {
	const PwaInstallSettingsButton({super.key});

	@override
	State<PwaInstallSettingsButton> createState() => _PwaInstallSettingsButtonState();
}

class _PwaInstallSettingsButtonState extends State<PwaInstallSettingsButton> {
	bool _canInstall = false;
	bool _iosHint = false;
	bool _loading = true;
	bool _installing = false;

	@override
	void initState() {
		super.initState();
		_refresh();
		if (kIsWeb && PwaInstallService.supported) {
			PwaInstallService.listenInstallAvailable(_refresh);
		}
	}

	Future<void> _refresh() async {
		if (!kIsWeb || !PwaInstallService.supported || PwaInstallService.isStandalone) {
			if (mounted) setState(() => _loading = false);
			return;
		}
		if (!mounted) return;
		setState(() {
			_canInstall = PwaInstallService.canInstall;
			_iosHint = PwaInstallService.isIosSafari;
			_loading = false;
		});
	}

	Future<void> _install() async {
		if (_iosHint) {
			if (!mounted) return;
			await showDialog<void>(
				context: context,
				builder: (ctx) => AlertDialog(
					title: const Text("Agregar a inicio"),
					content: const Text(
						"Compartir → «Agregar a inicio» → «Agregar».",
					),
					actions: [
						FilledButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text("Entendido"),
						),
					],
				),
			);
			return;
		}
		setState(() => _installing = true);
		try {
			await PwaInstallService.promptInstall();
		} finally {
			if (mounted) {
				setState(() {
					_installing = false;
					_canInstall = PwaInstallService.canInstall;
				});
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		if (!kIsWeb || _loading || PwaInstallService.isStandalone) {
			return const SizedBox.shrink();
		}
		if (!_canInstall && !_iosHint) return const SizedBox.shrink();

		return SizedBox(
			height: 52,
			width: double.infinity,
			child: OutlinedButton.icon(
				onPressed: _installing ? null : _install,
				icon: _installing
						? const SizedBox(
								width: 20,
								height: 20,
								child: CircularProgressIndicator(strokeWidth: 2),
							)
						: const Icon(Icons.install_mobile_outlined),
				label: Text(
					_iosHint ? "AGREGAR A INICIO (IPHONE)" : "INSTALAR APP",
					style: const TextStyle(fontWeight: FontWeight.bold),
				),
				style: OutlinedButton.styleFrom(
					foregroundColor: Colors.black87,
					side: const BorderSide(color: Colors.black87, width: 1.2),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					),
				),
			),
		);
	}
}
