import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart" show ImagePicker, ImageSource;

import "../../../core/images/order_photo_compress.dart";
import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../application/mis_pedidos_mantenimiento_provider.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../domain/order_priority.dart";
import "widgets/mobile_sheet_select_field.dart";
import "widgets/order_hub_bottom_bar.dart";

/// Formulario **Hacer pedido** (potenciamiento) según mockup.
class PlaceOrderScreen extends ConsumerStatefulWidget {
	const PlaceOrderScreen({super.key});

	@override
	ConsumerState<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends ConsumerState<PlaceOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();

	String? _tipoProducto;
	OrderPriority? _prioridad;
	bool _loading = false;
	bool _compressingPhoto = false;
	Uint8List? _photoJpeg;

	final ImagePicker _picker = ImagePicker();

  static const List<String> _tiposProducto = [
    "Materiales",
    "Herramientas",
    "Repuestos",
    "Consumibles",
    "Otro",
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

	void _soon(BuildContext context, String msg) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$msg — próximamente.")),
		);
	}

	Future<void> _pickPhoto(ImageSource source) async {
		try {
			final xfile = await _picker.pickImage(source: source);
			if (xfile == null || !mounted) return;

			setState(() => _compressingPhoto = true);
			final raw = await xfile.readAsBytes();
			final compressed = await compute(compressOrderPhotoBytes, raw);
			if (!mounted) return;

			setState(() => _compressingPhoto = false);

			if (compressed == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text("No se pudo leer la imagen. Probá con otra foto o formato."),
					),
				);
				return;
			}

			if (compressed.length > kMaxOrderPhotoBytes) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text("No se pudo reducir la foto por debajo de 1,5 MB. Probá otra imagen."),
					),
				);
				return;
			}

			setState(() => _photoJpeg = compressed);
			final kb = (compressed.length / 1024).toStringAsFixed(1);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("Foto lista para enviar (~$kb KB, comprimida).")),
			);
		} catch (e) {
			if (mounted) {
				setState(() => _compressingPhoto = false);
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text("No se pudo obtener la foto: $e")),
				);
			}
		}
	}

	Future<void> _showPhotoSourceSheet() async {
		await showSlowModalBottomSheet<void>(
			context: context,
			builder: (ctx) => Material(
				color: Colors.white,
				shape: const RoundedRectangleBorder(
					borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
				),
				child: SafeArea(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							ListTile(
								leading: const Icon(Icons.photo_camera_outlined),
								title: const Text("Sacar foto"),
								onTap: () {
									Navigator.pop(ctx);
									_pickPhoto(ImageSource.camera);
								},
							),
							ListTile(
								leading: const Icon(Icons.photo_library_outlined),
								title: const Text("Elegir de la galería"),
								onTap: () {
									Navigator.pop(ctx);
									_pickPhoto(ImageSource.gallery);
								},
							),
						],
					),
				),
			),
		);
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;

		final perfil = await ref.read(currentProfileProvider.future);
		if (!appRolePuedeCrearPedidoMantenimiento(perfil?.rol)) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text(
						"Solo Mantenimiento, Admin o Superadmin pueden enviar este pedido al supervisor.",
					),
				),
			);
			return;
		}

		setState(() => _loading = true);
		try {
			final nombre = perfil!.nombre?.trim();
			final usuario = perfil.usuario?.trim();
			final display = (nombre != null && nombre.isNotEmpty)
					? nombre
					: (usuario != null && usuario.isNotEmpty)
							? usuario
							: "Mantenimiento";
			final solicitanteDisplay =
					"$display · ${perfil.rol?.label ?? "MANTENIMIENTO"}";

			await ref.read(maintenanceOrdersRepositoryProvider).createOrder(
						solicitanteDisplay: solicitanteDisplay,
						productName: _nombreCtrl.text.trim(),
						quantity: int.parse(_cantidadCtrl.text.trim()),
						productType: _tipoProducto!,
						priority: _prioridad!.dbValue,
						destination: _destinoCtrl.text.trim(),
					);
			ref.invalidate(maintenanceOrdersProvider);
			ref.invalidate(misPedidosMantenimientoProvider);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text(
						"Pedido enviado. El supervisor lo revisará y definirá si hay stock.",
					),
				),
			);
			_nombreCtrl.clear();
			_cantidadCtrl.clear();
			_destinoCtrl.clear();
			setState(() {
				_tipoProducto = null;
				_prioridad = null;
				_photoJpeg = null;
			});
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo guardar el pedido: $e")),
			);
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTokens.surfacePage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlaceOrderHeader(
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go("/home");
              }
            },
            onRefresh: () => ScreenRefresh.mantenimientoHome(ref),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "NOMBRE DEL PRODUCTO",
                            style: AuthFieldStyles.labelAbove,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nombreCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: AuthFieldStyles.outline(
                            hintText: "Ingrese nombre del producto",
                            prefixIcon: Icons.label_outline,
                          ),
                          validator: (v) {
                            if ((v ?? "").trim().length < 2) {
                              return "Requerido";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "CANTIDAD",
                            style: AuthFieldStyles.labelAbove,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cantidadCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: AuthFieldStyles.outline(
                            hintText: "Ingrese cantidad",
                            prefixIcon: Icons.numbers,
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? "").trim());
                            if (n == null || n < 1) {
                              return "Indicá una cantidad válida";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "TIPO DE PRODUCTO",
                            style: AuthFieldStyles.labelAbove,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MobileSheetSelectFormField<String>(
                          value: _tipoProducto,
                          options: _tiposProducto,
                          labelOf: (t) => t,
                          hintText: "Seleccionar…",
                          prefixIcon: Icons.category_outlined,
                          title: "Tipo de producto",
                          enabled: !_loading,
                          onChanged: (v) => setState(() => _tipoProducto = v),
                          validator: (v) => v == null ? "Elegí un tipo" : null,
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "PRIORIDAD",
                            style: AuthFieldStyles.labelAbove,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MobileSheetSelectFormField<OrderPriority>(
                          value: _prioridad,
                          options: OrderPriority.values.toList(),
                          labelOf: (p) => p.label,
                          hintText: "Seleccionar…",
                          prefixIcon: Icons.flag_outlined,
                          title: "Prioridad",
                          enabled: !_loading,
                          onChanged: (v) => setState(() => _prioridad = v),
                          validator: (v) =>
                              v == null ? "Elegí prioridad" : null,
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "PARA DÓNDE ES",
                            style: AuthFieldStyles.labelAbove,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _destinoCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: AuthFieldStyles.outline(
                            hintText: "Ingrese destino",
                            prefixIcon: Icons.place_outlined,
                          ),
													validator: (v) {
														if ((v ?? "").trim().length < 2) {
															return "Requerido";
														}
														return null;
													},
												),
												const SizedBox(height: 18),
												Align(
													alignment: Alignment.centerLeft,
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text(
																"FOTO (opcional)",
																style: AuthFieldStyles.labelAbove,
															),
															const SizedBox(height: 4),
															Text(
																"Se comprime automáticamente a menos de 1,5 MB.",
																style: TextStyle(
																	fontSize: 12,
																	color: Colors.grey.shade600,
																),
															),
														],
													),
												),
												const SizedBox(height: 10),
												Row(
													children: [
														Expanded(
															child: OutlinedButton.icon(
																onPressed: _loading || _compressingPhoto
																	? null
																	: _showPhotoSourceSheet,
																icon: _compressingPhoto
																	? SizedBox(
																			width: 18,
																			height: 18,
																			child: CircularProgressIndicator(
																				strokeWidth: 2,
																				color: Colors.grey.shade700,
																			),
																		)
																	: const Icon(Icons.add_a_photo_outlined, size: 20),
																label: Text(
																	_compressingPhoto ? "Comprimiendo…" : "Foto",
																),
															),
														),
														if (_photoJpeg != null) ...[
															const SizedBox(width: 10),
															IconButton.filledTonal(
																onPressed: _loading || _compressingPhoto
																	? null
																	: () => setState(() => _photoJpeg = null),
																icon: const Icon(Icons.delete_outline),
																tooltip: "Quitar foto",
															),
														],
													],
												),
												if (_photoJpeg != null) ...[
													const SizedBox(height: 12),
													ClipRRect(
														borderRadius: BorderRadius.circular(AppTokens.radiusMd),
														child: AspectRatio(
															aspectRatio: 16 / 10,
															child: Image.memory(
																_photoJpeg!,
																fit: BoxFit.cover,
																gaplessPlayback: true,
															),
														),
													),
													const SizedBox(height: 6),
													Text(
														"Peso final: ${(_photoJpeg!.length / 1024).toStringAsFixed(1)} KB · máx. ${(kMaxOrderPhotoBytes / 1024).toStringAsFixed(0)} KB",
														style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
													),
												],
												const SizedBox(height: 28),
												SizedBox(
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTokens.redAction,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusMd,
                                ),
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "ENVIAR",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(Icons.send_rounded, size: 22),
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
          OrderHubBottomBar(
            bottomPadding: bottomInset,
            selectedIndex: 0,
            onPedido: () {},
            onHistorial: () => _soon(context, "Historial de pedidos"),
            onPerfil: () => _soon(context, "Perfil"),
          ),
        ],
      ),
    );
  }
}

class _PlaceOrderHeader extends StatelessWidget {
  const _PlaceOrderHeader({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTokens.yellowHeader,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: onBack,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  "HACER PEDIDO",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 0.8,
                    color: Colors.black87,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black87),
                  tooltip: "Recargar",
                  onPressed: onRefresh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
