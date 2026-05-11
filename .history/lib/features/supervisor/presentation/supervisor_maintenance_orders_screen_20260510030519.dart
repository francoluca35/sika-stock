import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_tokens.dart";
import "../application/maintenance_orders_provider.dart";
import "../domain/maintenance_order.dart";

/// Tabla de **pedidos de mantenimiento** para supervisor (lista mockup).
class SupervisorMaintenanceOrdersScreen extends ConsumerWidget {
  const SupervisorMaintenanceOrdersScreen({super.key});

  static final DateFormat _fechaFmt = DateFormat("dd/MM/yyyy HH:mm");

  static String _estadoLabel(MaintenanceOrderStatus s) {
    switch (s) {
      case MaintenanceOrderStatus.pendiente:
        return "PENDIENTE";
      case MaintenanceOrderStatus.enviado:
        return "ENVIADO";
      case MaintenanceOrderStatus.enProceso:
        return "EN PROCESO";
      case MaintenanceOrderStatus.completado:
        return "COMPLETADO";
    }
  }

  static (Color bg, Color fg) _estadoColors(MaintenanceOrderStatus s) {
    switch (s) {
      case MaintenanceOrderStatus.pendiente:
        return (AppTokens.yellowHeader, Colors.black87);
      case MaintenanceOrderStatus.enviado:
        return (AppTokens.statusOk, Colors.white);
      case MaintenanceOrderStatus.enProceso:
        return (AppTokens.roleMantenimientoBg, Colors.white);
      case MaintenanceOrderStatus.completado:
        return (AppTokens.blackNav, Colors.white);
    }
  }

  void _mostrarDetalle(BuildContext context, MaintenanceOrder o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        final (ebg, efg) = _estadoColors(o.estado);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 16 + bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  o.numeroOrden,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  label: "Quién lo pidió",
                  value: o.solicitante,
                ),
                _DetailRow(
                  label: "Cuándo se pidió",
                  value: _fechaFmt.format(o.fechaPedido),
                ),
                _DetailRow(
                  label: "Producto",
                  value: o.producto,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          "Estado",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _EstadoChip(
                            label: _estadoLabel(o.estado),
                            background: ebg,
                            foreground: efg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Para qué / motivo",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        o.motivo,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (o.imagenUrl != null && o.imagenUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Imagen adjunta",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        o.imagenUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _consultar(BuildContext context, MaintenanceOrder o) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Consultar ${o.numeroOrden} — próximamente."),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(maintenanceOrdersProvider);
    final n = pedidos.length;

    return Scaffold(
      backgroundColor: AppTokens.surfacePage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContenedorTituloRojo(
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go("/home");
              }
            },
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTokens.maxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTokens.whiteSurface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(color: AppTokens.greyBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Table(
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    columnWidths: const {
                                      0: FixedColumnWidth(108),
                                      1: FixedColumnWidth(148),
                                      2: FixedColumnWidth(200),
                                      3: FixedColumnWidth(128),
                                      4: FixedColumnWidth(200),
                                    },
                                    border: TableBorder.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                    children: [
                                      TableRow(
                                        decoration: const BoxDecoration(
                                          color: AppTokens.yellowHeader,
                                        ),
                                        children: [
                                          for (final t in [
                                            "N° ORDEN",
                                            "FECHA",
                                            "PRODUCTO",
                                            "ESTADO",
                                            "INFO",
                                          ])
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                              child: Text(
                                                t,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      for (var i = 0; i < pedidos.length; i++)
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: i.isEven
                                                ? AppTokens.whiteSurface
                                                : AppTokens.surfaceMuted,
                                          ),
                                          children: [
                                            _celdaTexto(pedidos[i].numeroOrden),
                                            _celdaTexto(
                                              _fechaFmt.format(
                                                pedidos[i].fechaPedido,
                                              ),
                                            ),
                                            _celdaTexto(pedidos[i].producto),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: _EstadoChip(
                                                  label: _estadoLabel(
                                                    pedidos[i].estado,
                                                  ),
                                                  background: _estadoColors(
                                                    pedidos[i].estado,
                                                  ).$1,
                                                  foreground: _estadoColors(
                                                    pedidos[i].estado,
                                                  ).$2,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 8,
                                              ),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  _TextActionButton(
                                                    label: "VER",
                                                    background:
                                                        AppTokens.yellowHeader,
                                                    foreground: Colors.black87,
                                                    onPressed: () =>
                                                        _mostrarDetalle(
                                                      context,
                                                      pedidos[i],
                                                    ),
                                                  ),
                                                  _TextActionButton(
                                                    label: "CONSULTAR",
                                                    background:
                                                        AppTokens.redAction,
                                                    foreground: Colors.white,
                                                    onPressed: () => _consultar(
                                                      context,
                                                      pedidos[i],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Text(
                            n == 0
                                ? "Sin pedidos"
                                : "Mostrando 1 a $n de $n pedidos",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color.fromARGB(255, 255, 238, 0),
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

  static Widget _celdaTexto(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }
}

class _ContenedorTituloRojo extends StatelessWidget {
  const _ContenedorTituloRojo({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color.fromARGB(255, 96, 81, 81),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
              const Expanded(
                child: Text(
                  "PEDIDOS DE MANTENIMIENTO",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
          color: foreground,
        ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
