import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../auth/domain/profile_row.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../../auth/presentation/widgets/auth_password_field.dart";
import "../application/admin_providers.dart";

/// Abre un panel tipo **celular** (desliza desde abajo) para editar usuario.
void showEditUserModal(BuildContext context, ProfileRow profile) {
	final rootCtx = context;
	showModalBottomSheet<void>(
		context: context,
		isScrollControlled: true,
		useSafeArea: true,
		backgroundColor: Colors.transparent,
		barrierColor: Colors.black.withValues(alpha: 0.45),
		elevation: 0,
		showDragHandle: false,
		builder: (modalContext) {
			return Padding(
				padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(modalContext).bottom),
				child: EditUserModal(
					profile: profile,
					snackbarContext: rootCtx,
				),
			);
		},
	);
}

class EditUserModal extends ConsumerStatefulWidget {
	const EditUserModal({
		super.key,
		required this.profile,
		required this.snackbarContext,
	});

	final ProfileRow profile;
	final BuildContext snackbarContext;

	@override
	ConsumerState<EditUserModal> createState() => _EditUserModalState();
}

class _EditUserModalState extends ConsumerState<EditUserModal> {
	final _formKey = GlobalKey<FormState>();
	final _emailCtrl = TextEditingController();
	final _nombreCtrl = TextEditingController();
	final _usuarioCtrl = TextEditingController();
	final _passCtrl = TextEditingController();
	final _confirmCtrl = TextEditingController();
	AppRole? _rol;
	bool _loading = false;

	@override
	void initState() {
		super.initState();
		final p = widget.profile;
		_emailCtrl.text = (p.email ?? "").trim();
		_nombreCtrl.text = (p.nombre ?? "").trim();
		_usuarioCtrl.text = (p.usuario ?? "").trim();
		_rol = p.rol;
	}

	@override
	void dispose() {
		_emailCtrl.dispose();
		_nombreCtrl.dispose();
		_usuarioCtrl.dispose();
		_passCtrl.dispose();
		_confirmCtrl.dispose();
		super.dispose();
	}

	static bool _isPrivileged(AppRole? r) =>
		r == AppRole.admin || r == AppRole.superadmin;

	List<AppRole> _rolesEdit(AppRole? caller, AppRole? targetRol) {
		final list = <AppRole>[
			AppRole.mantenimiento,
			AppRole.supervisor,
			AppRole.panol,
			AppRole.compras,
		];
		if (caller == AppRole.superadmin) {
			list.add(AppRole.superadmin);
			if (targetRol == AppRole.admin) {
				list.add(AppRole.admin);
			}
		}
		if (targetRol != null && !list.contains(targetRol)) {
			list.add(targetRol);
		}
		list.sort((a, b) => a.label.compareTo(b.label));
		return list;
	}

	bool _blockedForCaller(AppRole? caller, ProfileRow target) {
		final tr = target.rol;
		if (tr != AppRole.admin && tr != AppRole.superadmin) {
			return false;
		}
		return caller != AppRole.superadmin;
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		if (_rol == null) {
			ScaffoldMessenger.of(widget.snackbarContext).showSnackBar(
				const SnackBar(content: Text("Seleccioná un rol.")),
			);
			return;
		}

		final pass = _passCtrl.text;
		final confirm = _confirmCtrl.text;
		if (pass.isNotEmpty || confirm.isNotEmpty) {
			if (pass.length < 6) {
				ScaffoldMessenger.of(widget.snackbarContext).showSnackBar(
					const SnackBar(content: Text("La contraseña debe tener al menos 6 caracteres.")),
				);
				return;
			}
			if (pass != confirm) {
				ScaffoldMessenger.of(widget.snackbarContext).showSnackBar(
					const SnackBar(content: Text("Las contraseñas no coinciden.")),
				);
				return;
			}
		}

		setState(() => _loading = true);
		final snackCtx = widget.snackbarContext;
		try {
			await ref.read(adminUsersRepositoryProvider).updateUser(
				userId: widget.profile.id,
				email: _emailCtrl.text,
				nombre: _nombreCtrl.text,
				usuario: _usuarioCtrl.text,
				rol: _rol!,
				password: pass.isEmpty ? null : pass,
			);
			if (!mounted) return;
			if (!context.mounted) return;
			Navigator.of(context).pop();
			ref.invalidate(usersListProvider);
			if (!snackCtx.mounted) return;
			ScaffoldMessenger.of(snackCtx).showSnackBar(
				const SnackBar(content: Text("Usuario actualizado correctamente.")),
			);
		} catch (e) {
			if (!mounted || !snackCtx.mounted) return;
			ScaffoldMessenger.of(snackCtx).showSnackBar(
				SnackBar(content: Text(e.toString())),
			);
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	void _closeSheet() {
		if (!_loading) Navigator.of(context).pop();
	}

	/// Panel ancho completo que sube desde abajo (altura en fracción de pantalla).
	Widget _mobileSheetChrome({
		required Widget child,
		required double heightFraction,
	}) {
		final h = MediaQuery.sizeOf(context).height;
		final height = (h * heightFraction).clamp(180.0, h * 0.96);
		return Align(
			alignment: Alignment.bottomCenter,
			child: SizedBox(
				height: height,
				width: double.infinity,
				child: ClipRRect(
					borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
					child: Material(
						color: Colors.white,
						elevation: 10,
						shadowColor: Colors.black26,
						child: child,
					),
				),
			),
		);
	}

	Widget _dragHandle() {
		return Padding(
			padding: const EdgeInsets.only(top: 10, bottom: 6),
			child: Center(
				child: Container(
					width: 40,
					height: 5,
					decoration: BoxDecoration(
						color: Colors.grey.shade300,
						borderRadius: BorderRadius.circular(40),
					),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final profileAsync = ref.watch(currentProfileProvider);

		return profileAsync.when(
			data: (p) {
				if (!_isPrivileged(p?.rol)) {
					WidgetsBinding.instance.addPostFrameCallback((_) {
						if (!context.mounted) return;
						Navigator.of(context).pop();
						if (widget.snackbarContext.mounted) {
							widget.snackbarContext.go("/home");
						}
					});
					return _mobileSheetChrome(
						heightFraction: 0.22,
						child: Padding(
							padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
							child: Row(
								children: [
									const SizedBox(
										height: 28,
										width: 28,
										child: CircularProgressIndicator(strokeWidth: 2),
									),
									const SizedBox(width: 16),
									Expanded(
										child: Text(
											"Comprobando permisos…",
											style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
										),
									),
								],
							),
						),
					);
				}

				final caller = p?.rol;
				if (_blockedForCaller(caller, widget.profile)) {
					return _mobileSheetChrome(
						heightFraction: 0.42,
						child: Padding(
							padding: const EdgeInsets.fromLTRB(20, 0, 12, 24),
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									_dragHandle(),
									Row(
										children: [
											const Expanded(
												child: Text(
													"Editar usuario",
													style: TextStyle(
														fontWeight: FontWeight.bold,
														fontSize: 18,
													),
												),
											),
											IconButton(
												icon: const Icon(Icons.close),
												onPressed: _closeSheet,
											),
										],
									),
									const SizedBox(height: 12),
									Text(
										"Solo un usuario SUPERADMIN puede editar cuentas con rol ADMIN o SUPERADMIN.",
										style: TextStyle(color: Colors.grey.shade800, height: 1.45, fontSize: 15),
									),
									const SizedBox(height: 22),
									SizedBox(
										width: double.infinity,
										height: 48,
										child: FilledButton(
											onPressed: _closeSheet,
											child: const Text("Cerrar"),
										),
									),
								],
							),
						),
					);
				}

				final roleItems = _rolesEdit(caller, widget.profile.rol);
				if (_rol != null && !roleItems.contains(_rol)) {
					WidgetsBinding.instance.addPostFrameCallback((_) {
						if (mounted) setState(() => _rol = widget.profile.rol);
					});
				}

				return _mobileSheetChrome(
					heightFraction: 0.9,
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							_dragHandle(),
							Padding(
								padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
								child: Row(
									children: [
										const Expanded(
											child: Text(
												"Editar usuario",
												style: TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 18,
												),
											),
										),
										IconButton(
											icon: const Icon(Icons.close),
											onPressed: _loading ? null : _closeSheet,
										),
									],
								),
							),
							Divider(height: 1, color: Colors.grey.shade200),
							Expanded(
								child: SingleChildScrollView(
									padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
									keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
									child: Form(
										key: _formKey,
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.stretch,
											children: [
												Text(
													"Modificá los datos o asigná una nueva contraseña.",
													style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
												),
												const SizedBox(height: 8),
												Text(
													"Dejá la contraseña en blanco si no querés cambiarla.",
													style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
												),
												const SizedBox(height: 18),
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
													child: Text(
														"NUEVA CONTRASEÑA (opcional)",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												AuthPasswordField(
													controller: _passCtrl,
													label: "CONTRASEÑA",
													hint: "Solo si querés cambiarla",
													labelInDecoration: false,
													validator: (v) {
														final t = v ?? "";
														if (t.isEmpty) return null;
														if (t.length < 6) return "Mínimo 6 caracteres";
														return null;
													},
												),
												const SizedBox(height: 18),
												Align(
													alignment: Alignment.centerLeft,
													child: Text("CONFIRMAR CONTRASEÑA", style: AuthFieldStyles.labelAbove),
												),
												const SizedBox(height: 8),
												AuthPasswordField(
													controller: _confirmCtrl,
													label: "CONFIRMAR",
													hint: "Repetir nueva contraseña",
													labelInDecoration: false,
													validator: (v) {
														final p0 = _passCtrl.text;
														if (p0.isEmpty && (v ?? "").isEmpty) return null;
														if ((v ?? "") != p0) return "No coincide";
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
													value: _rol != null && roleItems.contains(_rol) ? _rol : null,
													decoration: AuthFieldStyles.outline(
														hintText: "Seleccioná rol",
														prefixIcon: Icons.groups_outlined,
													),
													items: [
														for (final r in roleItems)
															DropdownMenuItem(value: r, child: Text(r.label)),
													],
													onChanged: _loading ? null : (v) => setState(() => _rol = v),
													validator: (v) => v == null ? "Elegí un rol" : null,
												),
												const SizedBox(height: 24),
												SizedBox(
													height: 50,
													width: double.infinity,
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
																	"GUARDAR CAMBIOS",
																	style: TextStyle(fontWeight: FontWeight.bold),
																),
													),
												),
											],
										),
									),
								),
							),
						],
					),
				);
			},
			loading: () => _mobileSheetChrome(
				heightFraction: 0.28,
				child: Padding(
					padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							_dragHandle(),
							const SizedBox(height: 12),
							const CircularProgressIndicator(),
							const SizedBox(height: 18),
							Text("Cargando…", style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
						],
					),
				),
			),
			error: (e, _) => _mobileSheetChrome(
				heightFraction: 0.38,
				child: Padding(
					padding: const EdgeInsets.fromLTRB(24, 12, 16, 28),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							_dragHandle(),
							const SizedBox(height: 8),
							Text("Error", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
							const SizedBox(height: 10),
							Text("$e", style: TextStyle(color: Colors.grey.shade800)),
							const SizedBox(height: 20),
							SizedBox(
								height: 48,
								child: FilledButton(
									onPressed: _closeSheet,
									child: const Text("Cerrar"),
								),
							),
						],
					),
				),
			),
		);
	}

	static bool _emailOk(String email) {
		return RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email);
	}
}
