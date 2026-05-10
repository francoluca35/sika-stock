import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/theme/app_tokens.dart";
import "../application/auth_providers.dart";
import "widgets/auth_field_styles.dart";
import "widgets/auth_password_field.dart";
import "widgets/login_brand_header.dart";

class LoginScreen extends ConsumerStatefulWidget {
	const LoginScreen({super.key});

	@override
	ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
	final _formKey = GlobalKey<FormState>();
	final _emailCtrl = TextEditingController();
	final _passwordCtrl = TextEditingController();
	bool _remember = false;
	bool _loading = false;

	@override
	void dispose() {
		_emailCtrl.dispose();
		_passwordCtrl.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _loading = true);
		final repo = ref.read(authRepositoryProvider);
		try {
			await repo.signInWithEmail(
				email: _emailCtrl.text,
				password: _passwordCtrl.text,
			);
			ref.invalidate(currentProfileProvider);
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(_mapAuthError(e))),
				);
			}
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Future<void> _forgotPassword() async {
		final email = _emailCtrl.text.trim();
		if (email.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Ingresá tu usuario (correo) primero.")),
			);
			return;
		}
		try {
			await ref.read(authRepositoryProvider).requestPasswordReset(email);
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text("Si el correo existe, recibirás instrucciones.")),
				);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(_mapAuthError(e))),
				);
			}
		}
	}

	static String _mapAuthError(Object e) {
		final s = e.toString().toLowerCase();
		if (s.contains("invalid login") ||
			s.contains("invalid_grant") ||
			s.contains("invalid_credentials")) {
			return "Correo o contraseña incorrectos.";
		}
		if (s.contains("email_not_confirmed") || s.contains("email not confirmed")) {
			return "Confirmá el correo desde el enlace que te enviamos.";
		}
		if (s.contains("user_banned") || s.contains("banned")) {
			return "Esta cuenta no puede iniciar sesión.";
		}
		if (s.contains("email_provider_disabled")) {
			return "El proveedor de correo no está habilitado en Supabase.";
		}
		if (s.contains("over_request_rate_limit") || s.contains("too many requests")) {
			return "Demasiados intentos. Probá de nuevo en unos minutos.";
		}
		return "No se pudo iniciar sesión.";
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppTokens.whiteSurface,
			body: Column(
				children: [
					const LoginBrandHeader(),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(22, 28, 22, 36),
							child: Center(
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 420),
									child: Form(
										key: _formKey,
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.stretch,
											children: [
												const Text(
													"INICIAR SESIÓN",
													textAlign: TextAlign.center,
													style: TextStyle(
														fontWeight: FontWeight.bold,
														fontSize: 22,
														color: Colors.black87,
													),
												),
												const SizedBox(height: 8),
												Text(
													"Ingresa tus credenciales para continuar",
													textAlign: TextAlign.center,
													style: TextStyle(
														fontSize: 13,
														color: Colors.grey.shade600,
													),
												),
												const SizedBox(height: 28),
												Align(
													alignment: Alignment.centerLeft,
													child: Text("USUARIO", style: AuthFieldStyles.labelAbove),
												),
												const SizedBox(height: 8),
												TextFormField(
													controller: _emailCtrl,
													keyboardType: TextInputType.emailAddress,
													autocorrect: false,
													style: const TextStyle(fontSize: 15),
													decoration: AuthFieldStyles.outline(
														hintText: "Ingresa tu usuario",
														prefixIcon: Icons.person_outline,
													),
													validator: (v) {
														final t = v?.trim() ?? "";
														if (t.isEmpty) return "Requerido";
														if (!_emailLooksValid(t)) return "Correo no válido";
														return null;
													},
												),
												const SizedBox(height: 18),
												Align(
													alignment: Alignment.centerLeft,
													child: Text("CONTRASEÑA", style: AuthFieldStyles.labelAbove),
												),
												const SizedBox(height: 8),
												AuthPasswordField(
													controller: _passwordCtrl,
													label: "CONTRASEÑA",
													hint: "Ingresa tu contraseña",
													labelInDecoration: false,
												),
												const SizedBox(height: 14),
												Row(
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														SizedBox(
															height: 42,
															width: 42,
															child: Checkbox(
																value: _remember,
																onChanged: _loading
																	? null
																	: (v) => setState(() => _remember = v ?? false),
																fillColor: WidgetStateProperty.resolveWith((states) {
																	if (states.contains(WidgetState.selected)) {
																		return AppTokens.yellowAccent;
																	}
																	return Colors.grey.shade300;
																}),
																checkColor: Colors.white,
																side: BorderSide(color: Colors.grey.shade400),
															),
														),
														const Expanded(
															child: Text(
																"Recordarme",
																style: TextStyle(fontSize: 14, color: Colors.black87),
															),
														),
														TextButton(
															onPressed: _loading ? null : _forgotPassword,
															style: TextButton.styleFrom(
																foregroundColor: AppTokens.redAction,
																padding: const EdgeInsets.symmetric(horizontal: 4),
															),
															child: const Text(
																"¿Olvidaste tu contraseña?",
																style: TextStyle(fontWeight: FontWeight.w500),
															),
														),
													],
												),
												const SizedBox(height: 22),
												SizedBox(
													height: 54,
													child: FilledButton(
														style: FilledButton.styleFrom(
															backgroundColor: AppTokens.redAction,
															foregroundColor: Colors.white,
															disabledBackgroundColor: Colors.grey,
															shape: RoundedRectangleBorder(
																borderRadius: BorderRadius.circular(AppTokens.radiusMd),
															),
															padding: const EdgeInsets.symmetric(horizontal: 18),
														),
														onPressed: _loading ? null : _submit,
														child: _loading
															? const SizedBox(
																	height: 22,
																	width: 22,
																	child: CircularProgressIndicator(
																		strokeWidth: 2,
																		color: Colors.white,
																	),
																)
															: const Row(
																	children: [
																		Expanded(
																			child: Text(
																				"INICIAR SESIÓN",
																				textAlign: TextAlign.center,
																				style: TextStyle(
																					fontWeight: FontWeight.bold,
																					fontSize: 15,
																					letterSpacing: 0.6,
																				),
																			),
																		),
																		Icon(Icons.login, color: Colors.white, size: 22),
																	],
																),
													),
												),
											],
										),
									),
								),
							),
						),
					),
				],
			),
		);
	}

	static bool _emailLooksValid(String email) {
		return RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email);
	}
}
