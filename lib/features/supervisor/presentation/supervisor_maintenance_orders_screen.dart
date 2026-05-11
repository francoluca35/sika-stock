import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../application/maintenance_orders_provider.dart";
import "../application/maintenance_stock_similarity.dart";
import "../domain/maintenance_order.dart";

bool _hayStockDisponibleParaPedido(
  MaintenanceOrder o,
  List<StockProduct> catalog,
) {
  final matches = stockSimilarToPedido(o.producto, catalog);
  return hayStockDisponibleEnCoincidencias(matches);
}

/// Tabla de **pedidos de mantenimiento** para supervisor (lista mockup).
class SupervisorMaintenanceOrdersScreen extends ConsumerStatefulWidget {
  const SupervisorMaintenanceOrdersScreen({super.key});

  /// Por debajo de este ancho se muestran tarjetas (sin scroll horizontal).
  static const double _tableLayoutMinWidth = 760;

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

  @override
  ConsumerState<SupervisorMaintenanceOrdersScreen> createState() =>
      _SupervisorMaintenanceOrdersScreenState();

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

class _SupervisorMaintenanceOrdersScreenState
    extends ConsumerState<SupervisorMaintenanceOrdersScreen> {
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
        final (ebg, efg) =
            SupervisorMaintenanceOrdersScreen._estadoColors(o.estado);
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
                      color: const Color.fromARGB(255, 213, 213, 5),
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
                  value: SupervisorMaintenanceOrdersScreen._fechaFmt.format(
                    o.fechaPedido,
                  ),
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
                            label: SupervisorMaintenanceOrdersScreen._estadoLabel(
                              o.estado,
                            ),
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

  void _retirarDesdeStock(BuildContext context, MaintenanceOrder o) {
    ref.read(maintenanceOrdersProvider.notifier).registrarRetiro(o.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Retiro registrado. ${o.numeroOrden} pasó al historial.",
        ),
      ),
    );
  }

  void _pedirAPanol(BuildContext context, MaintenanceOrder o) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Pedido a pañol: ${o.producto} (${o.numeroOrden}) — próximamente.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(maintenanceOrdersProvider);
    final catalog = ref.watch(supervisorStockCatalogProvider);
    final n = pedidos.length;

    return Scaffold(
      backgroundColor: AppTokens.surfacePage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PedidosMantenimientoBar(
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go("/home");
              }
            },
          ),
          Expanded(
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (pedidos.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  "Sin pedidos",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }
                          final useTable =
                              constraints.maxWidth >=
                                  SupervisorMaintenanceOrdersScreen
                                      ._tableLayoutMinWidth;
                          if (useTable) {
                            return Scrollbar(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: Table(
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  columnWidths: const {
                                    0: FlexColumnWidth(1),
                                    1: FlexColumnWidth(1.15),
                                    2: FlexColumnWidth(1.85),
                                    3: FlexColumnWidth(1),
                                    4: FlexColumnWidth(1.2),
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
                                            padding: const EdgeInsets.symmetric(
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
                                      () {
                                        final fila = pedidos[i];
                                        final hayStock =
                                            _hayStockDisponibleParaPedido(
                                          fila,
                                          catalog,
                                        );
                                        return TableRow(
                                          decoration: BoxDecoration(
                                            color: i.isEven
                                                ? AppTokens.whiteSurface
                                                : AppTokens.surfaceMuted,
                                          ),
                                          children: [
                                            SupervisorMaintenanceOrdersScreen
                                                ._celdaTexto(fila.numeroOrden),
                                            SupervisorMaintenanceOrdersScreen
                                                ._celdaTexto(
                                              SupervisorMaintenanceOrdersScreen
                                                  ._fechaFmt
                                                  .format(fila.fechaPedido),
                                            ),
                                            SupervisorMaintenanceOrdersScreen
                                                ._celdaTexto(fila.producto),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: _EstadoChip(
                                                  label:
                                                      SupervisorMaintenanceOrdersScreen
                                                          ._estadoLabel(
                                                    fila.estado,
                                                  ),
                                                  background:
                                                      SupervisorMaintenanceOrdersScreen
                                                          ._estadoColors(
                                                    fila.estado,
                                                  ).$1,
                                                  foreground:
                                                      SupervisorMaintenanceOrdersScreen
                                                          ._estadoColors(
                                                    fila.estado,
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
                                                      fila,
                                                    ),
                                                  ),
                                                  _TextActionButton(
                                                    label: hayStock
                                                        ? "RETIRAR"
                                                        : "PEDIR",
                                                    background:
                                                        AppTokens.redAction,
                                                    foreground: Colors.white,
                                                    onPressed: () {
                                                      if (hayStock) {
                                                        _retirarDesdeStock(
                                                          context,
                                                          fila,
                                                        );
                                                      } else {
                                                        _pedirAPanol(
                                                          context,
                                                          fila,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }(),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: pedidos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final o = pedidos[index];
                              final hayStock =
                                  _hayStockDisponibleParaPedido(o, catalog);
                              return _MobileMaintenanceOrderCard(
                                index: index,
                                order: o,
                                fechaText:
                                    SupervisorMaintenanceOrdersScreen._fechaFmt
                                        .format(o.fechaPedido),
                                estadoLabel:
                                    SupervisorMaintenanceOrdersScreen._estadoLabel(
                                  o.estado,
                                ),
                                estadoBg:
                                    SupervisorMaintenanceOrdersScreen
                                        ._estadoColors(o.estado)
                                        .$1,
                                estadoFg:
                                    SupervisorMaintenanceOrdersScreen
                                        ._estadoColors(o.estado)
                                        .$2,
                                onVer: () => _mostrarDetalle(context, o),
                                secondaryLabel:
                                    hayStock ? "RETIRAR" : "PEDIR",
                                onSecondary: () {
                                  if (hayStock) {
                                    _retirarDesdeStock(context, o);
                                  } else {
                                    _pedirAPanol(context, o);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (n > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Text(
                          "Mostrando 1 a $n de $n pedidos",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
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
  }
}

class _PedidosMantenimientoBar extends StatelessWidget {
  const _PedidosMantenimientoBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTokens.yellowHeader,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: onBack,
              ),
              const Expanded(
                child: Text(
                  "PEDIDOS DE MANTENIMIENTO",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
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

class _MobileMaintenanceOrderCard extends StatelessWidget {
  const _MobileMaintenanceOrderCard({
    required this.index,
    required this.order,
    required this.fechaText,
    required this.estadoLabel,
    required this.estadoBg,
    required this.estadoFg,
    required this.onVer,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final int index;
  final MaintenanceOrder order;
  final String fechaText;
  final String estadoLabel;
  final Color estadoBg;
  final Color estadoFg;
  final VoidCallback onVer;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final bg = index.isEven
        ? AppTokens.whiteSurface
        : AppTokens.surfaceMuted;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onVer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.greyBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                order.numeroOrden,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fechaText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.producto,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _EstadoChip(
                  label: estadoLabel,
                  background: estadoBg,
                  foreground: estadoFg,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextActionButton(
                      label: "VER",
                      background: AppTokens.yellowHeader,
                      foreground: Colors.black87,
                      onPressed: onVer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TextActionButton(
                      label: secondaryLabel,
                      background: AppTokens.redAction,
                      foreground: Colors.white,
                      onPressed: onSecondary,
                    ),
                  ),
                ],
              ),
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
