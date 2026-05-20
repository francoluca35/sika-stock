import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/format/argentina_datetime.dart";
import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../../panol/application/panol_forwarded_orders_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../orders/application/mantenimiento_notificaciones_provider.dart";
import "../application/maintenance_orders_provider.dart";
import "../application/maintenance_stock_similarity.dart"
		show analizarStockLineaExacta, analizarStockPedido;
import "../domain/maintenance_order.dart";

/// Tabla de **pedidos de mantenimiento** para supervisor (lista mockup).
class SupervisorMaintenanceOrdersScreen extends ConsumerStatefulWidget {
  const SupervisorMaintenanceOrdersScreen({super.key});

  /// Por debajo de este ancho se muestran tarjetas (sin scroll horizontal).
  static const double _tableLayoutMinWidth = 760;

  static String _formatFecha(DateTime d) => ArgentinaDateTime.formatDateTime(d);

  static String _workflowBadgeLabel(MaintenanceOrder o) {
    switch (o.workflowStatus) {
      case MaintenanceWorkflowStatus.pendingSupervisor:
        return "ESPERA SUPERVISOR";
      case MaintenanceWorkflowStatus.supervisorStockOk:
        return "STOCK OK";
      case MaintenanceWorkflowStatus.forwardedToPanol:
        return "EN PAÑOL";
      case MaintenanceWorkflowStatus.panolRequestedCompras:
        return "EN COMPRAS";
      case MaintenanceWorkflowStatus.comprasOcNotified:
        return "CONSULTA OC";
      case MaintenanceWorkflowStatus.comprasPurchaseDone:
        return "COMPRA HECHA";
      case MaintenanceWorkflowStatus.comprasArrivedNotified:
        return "EN PLANTA";
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
      case MaintenanceWorkflowStatus.panolRequestedCompras:
        return (Colors.amber.shade700, Colors.black87);
      case MaintenanceWorkflowStatus.comprasOcNotified:
        return (AppTokens.roleMantenimientoBg, Colors.white);
      case MaintenanceWorkflowStatus.comprasPurchaseDone:
        return (Colors.deepOrange.shade700, Colors.white);
      case MaintenanceWorkflowStatus.comprasArrivedNotified:
        return (AppTokens.statusOk, Colors.white);
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
  final Map<String, StockProduct?> _catalogOverrideByOrderId = {};

  ({bool haySuficiente, StockProduct? match, int disponible}) _analisisParaOrden(
    MaintenanceOrder o,
    List<StockProduct> catalog,
  ) {
    final pick = _catalogOverrideByOrderId[o.id];
    if (pick != null) {
      return analizarStockLineaExacta(pick, o.quantity);
    }
    return analizarStockPedido(o, catalog);
  }

  Future<void> _elegirProductoCatalogo(
    BuildContext context,
    MaintenanceOrder o,
    List<StockProduct> catalog,
  ) async {
    final buscar = TextEditingController();
    StockProduct? temp;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              List<StockProduct> filtrar() {
                final q = buscar.text.trim().toLowerCase();
                final list = catalog.where((p) {
                  if (q.isEmpty) return true;
                  return p.nombre.toLowerCase().contains(q) ||
                      p.categoria.toLowerCase().contains(q) ||
                      (p.codigo ?? "").toLowerCase().contains(q);
                }).toList();
                list.sort(
                  (a, b) =>
                      a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
                );
                return list;
              }

              final listado = filtrar();
              final h = MediaQuery.sizeOf(ctx).height * 0.72;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SizedBox(
                  height: h,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          "Elegir producto del catálogo",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: buscar,
                          decoration: const InputDecoration(
                            labelText: "Buscar",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setModal(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: listado.length,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemBuilder: (c, i) {
                            final p = listado[i];
                            final es = temp?.id == p.id;
                            return ListTile(
                              dense: true,
                              selected: es,
                              title: Text(p.nombre),
                              subtitle: Text(
                                "${p.categoria} · ${p.cantidad} u."
                                "${p.codigo != null && p.codigo!.isNotEmpty ? " · ${p.codigo}" : ""}",
                              ),
                              onTap: () => setModal(() => temp = p),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(
                                  () => _catalogOverrideByOrderId.remove(o.id),
                                );
                                Navigator.pop(ctx);
                              },
                              child: const Text("Quitar elección"),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancelar"),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: temp == null
                                  ? null
                                  : () {
                                      setState(
                                        () =>
                                            _catalogOverrideByOrderId[o.id] =
                                                temp,
                                      );
                                      Navigator.pop(ctx);
                                    },
                              child: const Text("Usar esta línea"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      buscar.dispose();
    }
  }

  Future<void> _mostrarDetalle(BuildContext context, MaintenanceOrder o) async {
    late final List<StockProduct> catalog;
    try {
      catalog = await ref.read(supervisorStockCatalogProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo cargar el stock: $e")),
      );
      return;
    }
    final analisis = _analisisParaOrden(o, catalog);
    if (!context.mounted) return;
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
                  value: SupervisorMaintenanceOrdersScreen._formatFecha(
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
                                  ? "Línea: ${analisis.match!.nombre} · Disponible: ${analisis.disponible} · Se piden: ${o.quantity} u."
                                  : "Línea: ${analisis.match!.nombre} · Disponible: ${analisis.disponible} (se piden ${o.quantity} u.). Derivá a pañol.",
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
                              "Sin coincidencia clara en catálogo. Elegí una línea o derivá a pañol.",
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
                                    if (analisis.haySuficiente &&
                                        analisis.match != null) {
                                      await _confirmarRetiroOk(
                                        context,
                                        o,
                                        catalog,
                                      );
                                    } else {
                                      await _decidirStock(
                                        context,
                                        o,
                                        hayStock: false,
                                      );
                                    }
                                  },
                                  child: Text(
                                    analisis.haySuficiente &&
                                            analisis.match != null
                                        ? "RETIRO OK"
                                        : "A PAÑOL",
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _elegirProductoCatalogo(context, o, catalog);
                            },
                            child: const Text("Elegir otra línea del catálogo"),
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
    final analisis = _analisisParaOrden(o, catalog);
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
          _TextActionButton(
            label: "ELEGIR",
            background: Colors.grey.shade200,
            foreground: Colors.black87,
            onPressed: () => _elegirProductoCatalogo(context, o, catalog),
          ),
          if (analisis.haySuficiente && analisis.match != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Text(
                _catalogOverrideByOrderId.containsKey(o.id)
                    ? "Línea elegida: ${analisis.match!.nombre}"
                    : "Catálogo OK",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade800,
                ),
              ),
            ),
            _TextActionButton(
              label: "RETIRO OK",
              background: AppTokens.statusOk,
              foreground: Colors.white,
              onPressed: () => _confirmarRetiroOk(context, o, catalog),
            ),
          ] else if (!analisis.haySuficiente) ...[
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
              label: "A PAÑOL",
              background: Colors.orange.shade800,
              foreground: Colors.white,
              onPressed: () => _decidirStock(context, o, hayStock: false),
            ),
          ] else if (analisis.haySuficiente && analisis.match == null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                "Usá ELEGIR y RETIRO OK",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
        ],
        if (o.workflowStatus ==
                MaintenanceWorkflowStatus.supervisorStockOk ||
            o.workflowStatus ==
                MaintenanceWorkflowStatus.comprasArrivedNotified)
          _TextActionButton(
            label: "RETIRO OK",
            background: AppTokens.statusOk,
            foreground: Colors.white,
            onPressed: () => _confirmarRetiroOk(context, o, catalog),
          ),
      ],
    );
  }

  Future<void> _confirmarRetiroOk(
    BuildContext context,
    MaintenanceOrder o,
    List<StockProduct> catalog,
  ) async {
    final analisis = _analisisParaOrden(o, catalog);
    final stockId = o.workflowStatus ==
            MaintenanceWorkflowStatus.pendingSupervisor
        ? analisis.match?.id
        : o.stockItemId;
    try {
      await ref.read(maintenanceOrdersProvider.notifier).confirmarRetiroOk(
            order: o,
            stockItemId: stockId,
          );
      if (!mounted) return;
      setState(() => _catalogOverrideByOrderId.remove(o.id));
      if (!context.mounted) return;
      final desconto =
          stockId != null && stockId.isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            desconto
                ? "RETIRO OK: ${o.numeroOrden} · pañol y mantenimiento avisados; "
                    "en historial; se descontaron ${o.quantity} u."
                : "RETIRO OK: ${o.numeroOrden} · pañol y mantenimiento avisados; en historial.",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo confirmar RETIRO OK: $e")),
      );
    }
  }

  Future<void> _decidirStock(
    BuildContext context,
    MaintenanceOrder o, {
    required bool hayStock,
    String? stockItemId,
  }) async {
    if (hayStock &&
        (stockItemId == null || stockItemId.trim().isEmpty)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Para confirmar retiro con stock tenés que tener una línea de catálogo (usá Elegir o esperá la coincidencia).",
          ),
        ),
      );
      return;
    }
    try {
      await ref.read(maintenanceOrdersProvider.notifier).supervisorDecideStock(
            orderId: o.id,
            hayStock: hayStock,
            stockItemId: stockItemId,
          );
      if (!hayStock) {
        ref.invalidate(panolForwardedOrdersProvider);
      }
      ref.invalidate(mantenimientoNotificacionesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Derivado a pañol: pañol fue notificado.",
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
    final catalogAsync = ref.watch(supervisorStockCatalogProvider);
    return asyncPedidos.when(
      loading: () => Scaffold(
        backgroundColor: AppTokens.surfacePage,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StockScreenHeader(
              title: "PEDIDOS DE MANTENIMIENTO",
              onBack: () => _onBack(context),
              onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
            ),
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
            StockScreenHeader(
              title: "PEDIDOS DE MANTENIMIENTO",
              onBack: () => _onBack(context),
              onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
            ),
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
        return catalogAsync.when(
          loading: () => Scaffold(
            backgroundColor: AppTokens.surfacePage,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StockScreenHeader(
                  title: "PEDIDOS DE MANTENIMIENTO",
                  onBack: () => _onBack(context),
                  onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
                ),
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
                StockScreenHeader(
                  title: "PEDIDOS DE MANTENIMIENTO",
                  onBack: () => _onBack(context),
                  onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "No se pudo cargar el catálogo de stock.\n$e",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => ref.invalidate(
                              supervisorStockCatalogProvider,
                            ),
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          data: (catalog) {
            final n = pedidos.length;
            return Scaffold(
      backgroundColor: AppTokens.surfacePage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StockScreenHeader(
            title: "PEDIDOS DE MANTENIMIENTO",
            onBack: () => _onBack(context),
            onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
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
                                            _analisisParaOrden(fila, catalog);
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
                                                  ._formatFecha(fila.fechaPedido),
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
                                                    _TextActionButton(
                                                      label: "ELEGIR",
                                                      background:
                                                          Colors.grey.shade200,
                                                      foreground: Colors.black87,
                                                      onPressed: () =>
                                                          _elegirProductoCatalogo(
                                                        context,
                                                        fila,
                                                        catalog,
                                                      ),
                                                    ),
                                                    if (analisis.haySuficiente &&
                                                        analisis.match != null)
                                                      _TextActionButton(
                                                        label: "RETIRO OK",
                                                        background:
                                                            AppTokens.statusOk,
                                                        foreground: Colors.white,
                                                        onPressed: () =>
                                                            _confirmarRetiroOk(
                                                          context,
                                                          fila,
                                                          catalog,
                                                        ),
                                                      )
                                                    else if (!analisis
                                                        .haySuficiente)
                                                      _TextActionButton(
                                                        label: "A PAÑOL",
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
                                                              .supervisorStockOk ||
                                                      fila.workflowStatus ==
                                                          MaintenanceWorkflowStatus
                                                              .comprasArrivedNotified)
                                                    _TextActionButton(
                                                      label: "RETIRO OK",
                                                      background:
                                                          AppTokens.statusOk,
                                                      foreground: Colors.white,
                                                      onPressed: () =>
                                                          _confirmarRetiroOk(
                                                        context,
                                                        fila,
                                                        catalog,
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
                                                        "Según catálogo o línea elegida",
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
                                SupervisorMaintenanceOrdersScreen._formatFecha(
                                    o.fechaPedido),
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
      },
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
