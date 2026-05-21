import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/profile_row.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../../auth/presentation/widgets/auth_password_field.dart";

/// Umbral: a partir de este ancho se usa layout de dos columnas (navegador / PC).
const double _kSettingsWideBreakpoint = 760;

/// Configuración de cuenta: nombre, usuario, correo y contraseña (todos los roles).
class AccountSettingsScreen extends ConsumerStatefulWidget {
	const AccountSettingsScreen({super.key});

	@override
	ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
	final _profileFormKey = GlobalKey<FormState>();
	final _passwordFormKey = GlobalKey<FormState>();
	final _nombreCtrl = TextEditingController();
	final _usuarioCtrl = TextEditingController();
	final _emailCtrl = TextEditingController();
	final _currentPassCtrl = TextEditingController();
	final _newPassCtrl = TextEditingController();
	final _confirmPassCtrl = TextEditingController();
	bool _fieldsLoaded = false;
	bool _savingProfile = false;
	bool _savingPassword = false;

	@override
	void dispose() {
		_nombreCtrl.dispose();
		_usuarioCtrl.dispose();
		_emailCtrl.dispose();
		_currentPassCtrl.dispose();
		_newPassCtrl.dispose();
		_confirmPassCtrl.dispose();
		super.dispose();
	}

	void _loadFieldsFromProfile(ProfileRow profile) {
		if (_fieldsLoaded) return;
		_nombreCtrl.text = profile.nombre?.trim() ?? "";
		_usuarioCtrl.text = profile.usuario?.trim() ?? "";
		_emailCtrl.text = profile.email?.trim() ?? "";
		_fieldsLoaded = true;
	}

	Future<void> _saveProfile() async {
		if (!_profileFormKey.currentState!.validate()) return;
		setState(() => _savingProfile = true);
		final repo = ref.read(authRepositoryProvider);
		try {
			await repo.updateOwnProfile(
				nombre: _nombreCtrl.text,
				usuario: _usuarioCtrl.text,
				email: _emailCtrl.text,
			);
			ref.invalidate(currentProfileProvider);
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text("Datos guardados correctamente.")),
				);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(_mapError(e))),
				);
			}
		} finally {
			if (mounted) setState(() => _savingProfile = false);
		}
	}

	Future<void> _savePassword() async {
		if (!_passwordFormKey.currentState!.validate()) return;
		setState(() => _savingPassword = true);
		final repo = ref.read(authRepositoryProvider);
		try {
			await repo.updateOwnPassword(
				currentPassword: _currentPassCtrl.text,
				newPassword: _newPassCtrl.text,
			);
			_currentPassCtrl.clear();
			_newPassCtrl.clear();
			_confirmPassCtrl.clear();
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text("Contraseña actualizada.")),
				);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(_mapError(e))),
				);
			}
		} finally {
			if (mounted) setState(() => _savingPassword = false);
		}
	}

	static bool _emailOk(String email) {
		return RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email);
	}

	static String _mapError(Object e) {
		final s = e.toString().toLowerCase();
		if (s.contains("invalid login") ||
			s.contains("invalid_grant") ||
			s.contains("invalid_credentials")) {
			return "La contraseña actual no es correcta.";
		}
		if (s.contains("same_password") || s.contains("same password")) {
			return "La nueva contraseña debe ser distinta a la actual.";
		}
		if (s.contains("weak_password") || s.contains("password")) {
			if (s.contains("at least") || s.contains("weak")) {
				return "La contraseña no cumple los requisitos de seguridad.";
			}
		}
		if (s.contains("email") && (s.contains("already") || s.contains("registered"))) {
			return "Ese correo ya está en uso.";
		}
		if (s.contains("email_change") || s.contains("confirmation")) {
			return "Revisá tu correo para confirmar el cambio de email.";
		}
		return "No se pudo guardar. Intentá de nuevo.";
	}

	Widget _buildIntro(ProfileRow profile, {required bool isWide}) {
		if (isWide) {
			return Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Expanded(
						child: Text(
							"Actualizá tus datos personales y contraseña. El rol lo asigna un administrador.",
							style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
						),
					),
					if (profile.rol != null) ...[
						const SizedBox(width: 16),
						Chip(
							label: Text(
								"Rol: ${profile.rol!.label}",
								style: const TextStyle(fontWeight: FontWeight.w600),
							),
							backgroundColor: Colors.grey.shade200,
						),
					],
				],
			);
		}
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Text(
					"Actualizá tus datos personales. El rol lo asigna un administrador.",
					style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
				),
				if (profile.rol != null) ...[
					const SizedBox(height: 12),
					Align(
						alignment: Alignment.centerLeft,
						child: Chip(
							label: Text(
								"Rol: ${profile.rol!.label}",
								style: const TextStyle(fontWeight: FontWeight.w600),
							),
							backgroundColor: Colors.grey.shade200,
						),
					),
				],
			],
		);
	}

	Widget _buildProfileFields() {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				const Text(
					"DATOS PERSONALES",
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 13,
						letterSpacing: 0.4,
					),
				),
				const SizedBox(height: 16),
				Align(
					alignment: Alignment.centerLeft,
					child: Text("NOMBRE", style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				TextFormField(
					controller: _nombreCtrl,
					textCapitalization: TextCapitalization.words,
					decoration: AuthFieldStyles.outline(
						hintText: "Nombre y apellido",
						prefixIcon: Icons.badge_outlined,
					),
					validator: (v) {
						if ((v ?? "").trim().length < 2) return "Requerido";
						return null;
					},
				),
				const SizedBox(height: 18),
				Align(
					alignment: Alignment.centerLeft,
					child: Text("USUARIO", style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				TextFormField(
					controller: _usuarioCtrl,
					autocorrect: false,
					decoration: AuthFieldStyles.outline(
						hintText: "Nombre de usuario",
						prefixIcon: Icons.person_outline,
					),
					validator: (v) {
						if ((v ?? "").trim().length < 2) return "Requerido";
						return null;
					},
				),
				const SizedBox(height: 18),
				Align(
					alignment: Alignment.centerLeft,
					child: Text("CORREO (GMAIL)", style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				TextFormField(
					controller: _emailCtrl,
					keyboardType: TextInputType.emailAddress,
					autocorrect: false,
					decoration: AuthFieldStyles.outline(
						hintText: "correo@gmail.com",
						prefixIcon: Icons.mail_outline,
					),
					validator: (v) {
						final t = v?.trim() ?? "";
						if (t.isEmpty) return "Requerido";
						if (!_emailOk(t)) return "Correo no válido";
						return null;
					},
				),
				const SizedBox(height: 8),
				Text(
					"Para iniciar sesión usás este correo. Si lo cambiás, puede pedirse confirmación por email.",
					style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
				),
				const SizedBox(height: 24),
				SizedBox(
					height: 52,
					child: FilledButton(
						style: FilledButton.styleFrom(
							backgroundColor: AppTokens.redAction,
							foregroundColor: Colors.white,
							shape: RoundedRectangleBorder(
								borderRadius: BorderRadius.circular(AppTokens.radiusMd),
							),
						),
						onPressed: _savingProfile ? null : _saveProfile,
						child: _savingProfile
							? const SizedBox(
									height: 22,
									width: 22,
									child: CircularProgressIndicator(
										strokeWidth: 2,
										color: Colors.white,
									),
								)
							: const Text(
									"GUARDAR DATOS",
									style: TextStyle(fontWeight: FontWeight.bold),
								),
					),
				),
			],
		);
	}

	Widget _buildPasswordFields() {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				const Text(
					"CONTRASEÑA",
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 13,
						letterSpacing: 0.4,
					),
				),
				const SizedBox(height: 16),
				Align(
					alignment: Alignment.centerLeft,
					child: Text("CONTRASEÑA ACTUAL", style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				AuthPasswordField(
					controller: _currentPassCtrl,
					label: "ACTUAL",
					hint: "Tu contraseña actual",
					labelInDecoration: false,
					validator: (v) {
						if ((v ?? "").isEmpty) return "Requerido";
						return null;
					},
				),
				const SizedBox(height: 18),
				Align(
					alignment: Alignment.centerLeft,
					child: Text("NUEVA CONTRASEÑA", style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				AuthPasswordField(
					controller: _newPassCtrl,
					label: "NUEVA",
					hint: "Mínimo 6 caracteres",
					labelInDecoration: false,
					validator: (v) {
						if ((v ?? "").length < 6) return "Mínimo 6 caracteres";
						return null;
					},
				),
				const SizedBox(height: 18),
				Align(
					alignment: Alignment.centerLeft,
					child: Text("REPETIR NUEVA", style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				AuthPasswordField(
					controller: _confirmPassCtrl,
					label: "CONFIRMAR",
					hint: "Repetir nueva contraseña",
					labelInDecoration: false,
					validator: (v) {
						if ((v ?? "").isEmpty) return "Requerido";
						if (v != _newPassCtrl.text) return "No coincide";
						return null;
					},
				),
				const SizedBox(height: 24),
				SizedBox(
					height: 52,
					child: OutlinedButton(
						style: OutlinedButton.styleFrom(
							foregroundColor: Colors.black87,
							side: const BorderSide(color: Colors.black87, width: 1.2),
							shape: RoundedRectangleBorder(
								borderRadius: BorderRadius.circular(AppTokens.radiusMd),
							),
						),
						onPressed: _savingPassword ? null : _savePassword,
						child: _savingPassword
							? const SizedBox(
									height: 22,
									width: 22,
									child: CircularProgressIndicator(strokeWidth: 2),
								)
							: const Text(
									"CAMBIAR CONTRASEÑA",
									style: TextStyle(fontWeight: FontWeight.bold),
								),
					),
				),
			],
		);
	}

	Widget _sectionCard({required Widget child}) {
		return Material(
			color: AppTokens.whiteSurface,
			elevation: 1,
			shadowColor: Colors.black12,
			borderRadius: BorderRadius.circular(AppTokens.radiusLg),
			child: Container(
				width: double.infinity,
				padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
				decoration: BoxDecoration(
					borderRadius: BorderRadius.circular(AppTokens.radiusLg),
					border: Border.all(color: Colors.black87, width: 1.1),
				),
				child: child,
			),
		);
	}

	Widget _buildSettingsBody(ProfileRow profile) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final isWide = constraints.maxWidth >= _kSettingsWideBreakpoint;
				final maxContentWidth = isWide ? AppTokens.maxContentWidth : 420.0;
				final scrollPad = isWide
					? const EdgeInsets.fromLTRB(32, 20, 32, 40)
					: AppTokens.padScreen.copyWith(top: 20, bottom: 40);

				return SingleChildScrollView(
					padding: scrollPad,
					child: Align(
						alignment: Alignment.topCenter,
						child: ConstrainedBox(
							constraints: BoxConstraints(maxWidth: maxContentWidth),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									_buildIntro(profile, isWide: isWide),
									SizedBox(height: isWide ? 28 : 24),
									if (isWide)
										IntrinsicHeight(
											child: Row(
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													Expanded(
														child: _sectionCard(
															child: Form(
																key: _profileFormKey,
																child: _buildProfileFields(),
															),
														),
													),
													const SizedBox(width: 24),
													Expanded(
														child: _sectionCard(
															child: Form(
																key: _passwordFormKey,
																child: _buildPasswordFields(),
															),
														),
													),
												],
											),
										)
									else ...[
										Form(
											key: _profileFormKey,
											child: _buildProfileFields(),
										),
										const SizedBox(height: 36),
										const Divider(),
										const SizedBox(height: 24),
										Form(
											key: _passwordFormKey,
											child: _buildPasswordFields(),
										),
									],
								],
							),
						),
					),
				);
			},
		);
	}

	@override
	Widget build(BuildContext context) {
		final profileAsync = ref.watch(currentProfileProvider);

		return profileAsync.when(
			data: (profile) {
				if (profile == null) {
					WidgetsBinding.instance.addPostFrameCallback((_) {
						if (context.mounted) context.go("/login");
					});
					return const Scaffold(
						body: Center(child: CircularProgressIndicator()),
					);
				}
				_loadFieldsFromProfile(profile);

				return Scaffold(
					backgroundColor: AppTokens.surfacePage,
					appBar: AppBar(
						title: const Text("Configuración"),
						leading: IconButton(
							icon: const Icon(Icons.arrow_back),
							onPressed: () {
								if (context.canPop()) {
									context.pop();
								} else {
									context.go("/home");
								}
							},
						),
					),
					body: _buildSettingsBody(profile),
				);
			},
			loading: () => const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			),
			error: (e, _) => Scaffold(
				appBar: AppBar(title: const Text("Configuración")),
				body: Center(
					child: Padding(
						padding: AppTokens.padScreen,
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Text("No se pudo cargar el perfil: $e"),
								const SizedBox(height: 16),
								TextButton(
									onPressed: () => ref.invalidate(currentProfileProvider),
									child: const Text("Reintentar"),
								),
							],
						),
					),
				),
			),
		);
	}
}
