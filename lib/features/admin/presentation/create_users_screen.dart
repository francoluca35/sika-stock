import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../../auth/presentation/widgets/auth_password_field.dart";
import "../application/admin_providers.dart";

/// Alta de usuarios por ADMIN / SUPERADMIN (Edge Function `create-user`).
class CreateUsersScreen extends ConsumerStatefulWidget {
	const CreateUsersScreen({super.key});

	@override
	ConsumerState<CreateUsersScreen> createState() => _CreateUsersScreenState();
}

class _CreateUsersScreenState extends ConsumerState<CreateUsersScreen> {
	final _formKey = GlobalKey<FormState>();
	final _emailCtrl = TextEditingController();
	final _passCtrl = TextEditingController();
	final _confirmCtrl = TextEditingController();
	final _nombreCtrl = TextEditingController();
	final _usuarioCtrl = TextEditingController();
	AppRole? _rol;
	bool _loading = false;

	@override
	void dispose() {
		_emailCtrl.dispose();
		_passCtrl.dispose();
		_confirmCtrl.dispose();
		_nombreCtrl.dispose();
		_usuarioCtrl.dispose();
		super.dispose();
	}

	static bool _isPrivileged(AppRole? r) =>
		r == AppRole.admin || r == AppRole.superadmin;

	List<AppRole> _rolesDisponibles(AppRole? caller) {
		final list = <AppRole>[
			AppRole.mantenimiento,
			AppRole.supervisor,
			AppRole.panol,
			AppRole.compras,
		];
		if (caller == AppRole.superadmin) {
			list.add(AppRole.superadmin);
		}
		return list;
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		if (_rol == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Seleccioná un rol.")),
			);
			return;
		}

		setState(() => _loading = true);
		try {
			await ref.read(adminUsersRepositoryProvider).createUser(
				email: _emailCtrl.text,
				password: _passCtrl.text,
				nombre: _nombreCtrl.text,
				usuario: _usuarioCtrl.text,
				rol: _rol!,
			);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Usuario creado correctamente.")),
			);
			_emailCtrl.clear();
			_passCtrl.clear();
			_confirmCtrl.clear();
			_nombreCtrl.clear();
			_usuarioCtrl.clear();
			setState(() => _rol = null);
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(e.toString())),
				);
			}
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final profileAsync = ref.watch(currentProfileProvider);

		return profileAsync.when(
			data: (p) {
				if (!_isPrivileged(p?.rol)) {
					WidgetsBinding.instance.addPostFrameCallback((_) {
						if (context.mounted) context.go("/home");
					});
					return const Scaffold(
						body: Center(child: CircularProgressIndicator()),
					);
				}
				final caller = p?.rol;
				return Scaffold(
					appBar: AppBar(
						title: const Text("Nuevos usuarios"),
						leading: IconButton(
							icon: const Icon(Icons.arrow_back),
							onPressed: () => context.go("/home"),
						),
					),
					body: SingleChildScrollView(
						padding: AppTokens.padScreen.copyWith(bottom: 32),
						child: Center(
							child: ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 420),
								child: Form(
									key: _formKey,
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											Text(
												"Dar de alta un usuario con rol.",
												style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
											),
											const SizedBox(height: 20),
											Align(
												alignment: Alignment.centerLeft,
												child: Text("CORREO", style: AuthFieldStyles.labelAbove),
											),
											const SizedBox(height: 8),
											TextFormField(
												controller: _emailCtrl,
												keyboardType: TextInputType.emailAddress,
												autocorrect: false,
												decoration: AuthFieldStyles.outline(
													hintText: "correo@ejemplo.com",
													prefixIcon: Icons.mail_outline,
												),
												validator: (v) {
													final t = v?.trim() ?? "";
													if (t.isEmpty) return "Requerido";
													if (!_emailOk(t)) return "Correo no válido";
													return null;
												},
											),
											const SizedBox(height: 18),
											Align(
												alignment: Alignment.centerLeft,
												child: Text("NOMBRE COMPLETO", style: AuthFieldStyles.labelAbove),
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
													hintText: "Nombre de usuario interno",
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
												child: Text("CONTRASEÑA TEMPORAL", style: AuthFieldStyles.labelAbove),
											),
											const SizedBox(height: 8),
											AuthPasswordField(
												controller: _passCtrl,
												label: "CONTRASEÑA",
												hint: "Contraseña inicial",
												labelInDecoration: false,
											),
											const SizedBox(height: 18),
											Align(
												alignment: Alignment.centerLeft,
												child: Text("REPETIR CONTRASEÑA", style: AuthFieldStyles.labelAbove),
											),
											const SizedBox(height: 8),
											AuthPasswordField(
												controller: _confirmCtrl,
												label: "CONFIRMAR",
												hint: "Repetir contraseña",
												labelInDecoration: false,
												validator: (v) {
													if ((v ?? "").isEmpty) return "Requerido";
													if (v != _passCtrl.text) return "No coincide";
													return null;
												},
											),
											const SizedBox(height: 18),
											Align(
												alignment: Alignment.centerLeft,
												child: Text("ROL", style: AuthFieldStyles.labelAbove),
											),
											const SizedBox(height: 8),
											DropdownButtonFormField<AppRole>(
												value: _rol,
												decoration: AuthFieldStyles.outline(
													hintText: "Seleccioná rol",
													prefixIcon: Icons.groups_outlined,
												),
												items: [
													for (final r in _rolesDisponibles(caller))
														DropdownMenuItem(value: r, child: Text(r.label)),
												],
												onChanged: _loading ? null : (v) => setState(() => _rol = v),
												validator: (v) => v == null ? "Elegí un rol" : null,
											),
											const SizedBox(height: 28),
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
														: const Text(
																"CREAR USUARIO",
																style: TextStyle(fontWeight: FontWeight.bold),
															),
												),
											),
										],
									),
								),
							),
						),
					),
				);
			},
			loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
			error: (e, _) => Scaffold(
				body: Center(child: Text("Error: $e")),
			),
		);
	}

	static bool _emailOk(String email) {
		return RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email);
	}
}
