import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_tokens.dart";
import "../../panol/application/panol_forwarded_orders_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../orders/application/mantenimiento_notificaciones_provider.dart";
import "../application/maintenance_orders_provider.dart";
import "../application/maintenance_stock_similarity.dart";
import "../domain/maintenance_order.dart";

/// Tabla de **pedidos de mantenimiento** para supervisor (lista mockup).
class SupervisorMaintenanceOrdersScreen extends ConsumerStatefulWidget {
  const SupervisorMaintenanceOrdersScreen({super.key});

  /// Por debajo de este ancho se muestran tarjetas (sin scroll horizontal).
  static const double _tableLayoutMinWidth = 760;

  static final DateFormat _fechaFmt = DateFormat("dd/MM/yyyy HH:mm");

  static String _workflowBadgeLabel(MaintenanceOrder o) {
    switch (o.workflowStatus) {
      case MaintenanceWorkflowStatus.pendingSupervisor:
        return "ESPERA SUPERVISOR";
      case MaintenanceWorkflowStatus.supervisorStockOk:
        return "STOCK OK";
      case MaintenanceWorkflowStatus.forwardedToPanol:
        return "EN PAÑOL";
      case MaintenanceWorkflowStatus.completed:
        return "COMPLETADO";
      case MaintenanceWorkflowStatus.cancelled:
        return "CANCELADO";
    }
  }

  static (Color bg, Color fg) _workflowBadgeColors(MaintenanceOrder o) {
    switch (o.workflowStatus) {
      case MaintenanceWorkflowStatus.pendingSupervisor:
        return (AppTokens.yellowHeader, Colors.black87);
      case MaintenanceWorkflowStatus.supervisorStockOk:
        return (AppTokens.statusOk, Colors.white);
      case MaintenanceWorkflowStatus.forwardedToPanol:
        return (AppTokens.rolePanolBg, AppTokens.rolePanolFg);
      case MaintenanceWorkflowStatus.completed:
        return (AppTokens.blackNav, Colors.white);
      case MaintenanceWorkflowStatus.cancelled:
        return (Colors.grey.shade700, Colors.white);
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
    final catalog = ref.read(supervisorStockCatalogProvider);
    final analisis = analizarStockPedido(o, catalog);
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
            SupervisorMaintenanceOrdersScreen._workflowBadgeColors(o);
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
                _DetailRow(
                  label: "Cantidad",
                  value: "${o.quantity}",
                ),
                _DetailRow(
                  label: "Tipo",
                  value: o.productType,
                ),
                _DetailRow(
                  label: "Prioridad",
                  value: o.priority,
                ),
                _DetailRow(
                  label: "Destino",
                  value: o.destination,
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
                            label: SupervisorMaintenanceOrdersScreen._workflowBadgeLabel(
                              o,
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
                if (o.workflowStatus ==
                    MaintenanceWorkflowStatus.pendingSupervisor) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: analisis.haySuficiente
                          ? const Color(0xFFE8F5E9)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: analisis.haySuficiente
                            ? const Color(0xFF2E7D32)
                            : Colors.orange.shade800,
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            analisis.haySuficiente
                                ? "Stock en catálogo"
                                : "Sin stock suficiente",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: analisis.haySuficiente
                                  ? const Color(0xFF1B5E20)
                                  : Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (analisis.match != null)
                            Text(
                              analisis.haySuficiente
                                  ? "Coincidencia: ${analisis.match!.nombre} · Disponible: ${analisis.disponible} · Pedido: ${o.quantity} u."
                                  : "Mejor coincidencia: ${analisis.match!.nombre} · Disponible: ${analisis.disponible} (se piden ${o.quantity} u.). Pedir a pañol.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: analisis.haySuficiente
                                    ? const Color(0xFF2E7D32)
                                    : Colors.orange.shade900,
                              ),
                            )
                          else
                            Text(
                              "No hay coincidencia clara en catálogo. Pedir a pañol.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: analisis.haySuficiente
                                        ? AppTokens.statusOk
                                        : Colors.orange.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
                                    await _decidirStock(
                                      context,
                                      o,
                                      hayStock: analisis.haySuficiente,
                                    );
                                  },
                                  child: Text(
                                    analisis.haySuficiente ? "ENVIAR" : "PEDIR A PAÑOL",
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _mobileFooterActions(
    BuildContext context,
    MaintenanceOrder o,
    List<StockProduct> catalog,
  ) {
    final analisis = analizarStockPedido(o, catalog);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        _TextActionButton(
          label: "VER",
          background: AppTokens.yellowHeader,
          foreground: Colors.black87,
          onPressed: () => _mostrarDetalle(context, o),
        ),
        if (o.workflowStatus ==
            MaintenanceWorkflowStatus.pendingSupervisor) ...[
          if (analisis.haySuficiente) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Text(
                "Catálogo OK",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade800,
                ),
              ),
            ),
            _TextActionButton(
              label: "ENVIAR",
              background: AppTokens.statusOk,
              foreground: Colors.white,
              onPressed: () => _decidirStock(context, o, hayStock: true),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  analisis.match != null
                      ? "Sin stock suficiente"
                      : "Sin coincidencia · pañol",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _TextActionButton(
              label: "PEDIR A PAÑOL",
              background: Colors.orange.shade800,
              foreground: Colors.white,
              onPressed: () => _decidirStock(context, o, hayStock: false),
            ),
          ],
        ],
        if (o.workflowStatus ==
            MaintenanceWorkflowStatus.supervisorStockOk)
          _TextActionButton(
            label: "RETIRAR",
            background: AppTokens.redAction,
            foreground: Colors.white,
            onPressed: () => _retirarDesdeStock(context, o),
          ),
      ],
    );
  }

  Future<void> _retirarDesdeStock(BuildContext context, MaintenanceOrder o) async {
    try {
      await ref.read(maintenanceOrdersProvider.notifier).registrarRetiro(o.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Retiro registrado. ${o.numeroOrden} pasó al historial.",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo registrar el retiro: $e")),
      );
    }
  }

  Future<void> _decidirStock(
    BuildContext context,
    MaintenanceOrder o, {
    required bool hayStock,
  }) async {
    try {
      await ref.read(maintenanceOrdersProvider.notifier).supervisorDecideStock(
            orderId: o.id,
            hayStock: hayStock,
          );
      if (!hayStock) {
        ref.invalidate(panolForwardedOrdersProvider);
      }
      ref.invalidate(mantenimientoNotificacionesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hayStock
                ? "Enviado. Mantenimiento recibió aviso para retirar."
                : "Enviado a pañol. Mantenimiento recibió aviso.",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo actualizar: $e")),
      );
    }
  }

  void _onBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go("/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPedidos = ref.watch(maintenanceOrdersProvider);
    final catalog = ref.watch(supervisorStockCatalogProvider);
    return asyncPedidos.when(
      loading: () => Scaffold(
        backgroundColor: AppTokens.surfacePage,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PedidosMantenimientoBar(onBack: () => _onBack(context)),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTokens.surfacePage,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PedidosMantenimientoBar(onBack: () => _onBack(context)),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "No se pudieron cargar los pedidos.\n$e",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      data: (pedidos) {
        final n = pedidos.length;
        return Scaffold(
      backgroundColor: AppTokens.surfacePage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PedidosMantenimientoBar(
            onBack: () => _onBack(context),
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
                                        final analisis =
                                            analizarStockPedido(fila, catalog);
                                        final (ebg, efg) =
                                            SupervisorMaintenanceOrdersScreen
                                                ._workflowBadgeColors(fila);
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
                                                          ._workflowBadgeLabel(
                                                    fila,
                                                  ),
                                                  background: ebg,
                                                  foreground: efg,
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
                                                  if (fila.workflowStatus ==
                                                      MaintenanceWorkflowStatus
                                                          .pendingSupervisor) ...[
                                                    if (analisis.haySuficiente)
                                                      _TextActionButton(
                                                        label: "ENVIAR",
                                                        background:
                                                            AppTokens.statusOk,
                                                        foreground: Colors.white,
                                                        onPressed: () =>
                                                            _decidirStock(
                                                          context,
                                                          fila,
                                                          hayStock: true,
                                                        ),
                                                      )
                                                    else
                                                      _TextActionButton(
                                                        label: "PEDIR A PAÑOL",
                                                        background: Colors
                                                            .orange.shade800,
                                                        foreground: Colors.white,
                                                        onPressed: () =>
                                                            _decidirStock(
                                                          context,
                                                          fila,
                                                          hayStock: false,
                                                        ),
                                                      ),
                                                  ],
                                                  if (fila.workflowStatus ==
                                                      MaintenanceWorkflowStatus
                                                          .supervisorStockOk)
                                                    _TextActionButton(
                                                      label: "RETIRAR",
                                                      background:
                                                          AppTokens.redAction,
                                                      foreground: Colors.white,
                                                      onPressed: () =>
                                                          _retirarDesdeStock(
                                                        context,
                                                        fila,
                                                      ),
                                                    ),
                                                  if (fila.workflowStatus ==
                                                          MaintenanceWorkflowStatus
                                                              .pendingSupervisor &&
                                                      analisis.haySuficiente)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        left: 4,
                                                        top: 4,
                                                      ),
                                                      child: Text(
                                                        "Automático según catálogo",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors
                                                              .green.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  if (fila.workflowStatus ==
                                                          MaintenanceWorkflowStatus
                                                              .pendingSupervisor &&
                                                      !analisis.haySuficiente)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        left: 4,
                                                        top: 4,
                                                      ),
                                                      child: Text(
                                                        analisis.match != null
                                                            ? "Sin stock suficiente"
                                                            : "Sin coincidencia en catálogo",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors
                                                              .orange.shade900,
                                                        ),
                                                      ),
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
                              return _MobileMaintenanceOrderCard(
                                index: index,
                                order: o,
                                fechaText:
                                    SupervisorMaintenanceOrdersScreen._fechaFmt
                                        .format(o.fechaPedido),
                                estadoLabel:
                                    SupervisorMaintenanceOrdersScreen
                                        ._workflowBadgeLabel(o),
                                estadoBg:
                                    SupervisorMaintenanceOrdersScreen
                                        ._workflowBadgeColors(o)
                                        .$1,
                                estadoFg:
                                    SupervisorMaintenanceOrdersScreen
                                        ._workflowBadgeColors(o)
                                        .$2,
                                onVer: () => _mostrarDetalle(context, o),
                                footerActions: _mobileFooterActions(context, o, catalog),
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
      },
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
    required this.footerActions,
  });

  final int index;
  final MaintenanceOrder order;
  final String fechaText;
  final String estadoLabel;
  final Color estadoBg;
  final Color estadoFg;
  final VoidCallback onVer;
  final Widget footerActions;

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
              footerActions,
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
