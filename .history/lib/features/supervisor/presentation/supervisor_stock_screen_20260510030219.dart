import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";

/// Consulta de **stock disponible** para supervisor: lista + búsqueda y filtros.
class SupervisorStockScreen extends ConsumerStatefulWidget {
  const SupervisorStockScreen({super.key});

  @override
  ConsumerState<SupervisorStockScreen> createState() =>
      _SupervisorStockScreenState();
}

class _SupervisorStockScreenState extends ConsumerState<SupervisorStockScreen> {
  final _buscarCtrl = TextEditingController();
  String? _categoria;
  bool _soloConStock = true;

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  List<String> _categoriasOrdenadas(List<StockProduct> productos) {
    final s = productos.map((p) => p.categoria).toSet().toList();
    s.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return s;
  }

  List<StockProduct> _filtrar(List<StockProduct> todos) {
    final q = _buscarCtrl.text.trim().toLowerCase();
    final list = todos.where((p) {
      if (_soloConStock && p.cantidad <= 0) return false;
      if (_categoria != null && p.categoria != _categoria) return false;
      if (q.isEmpty) return true;
      final enNombre = p.nombre.toLowerCase().contains(q);
      final enCat = p.categoria.toLowerCase().contains(q);
      final enCod = (p.codigo ?? "").toLowerCase().contains(q);
      return enNombre || enCat || enCod;
    }).toList();
    list.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(supervisorStockCatalogProvider);
    final filtrados = _filtrar(productos);
    final categorias = _categoriasOrdenadas(productos);

    return Scaffold(
      backgroundColor: AppTokens.surfacePage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StockScreenHeader(
            title: "STOCK DISPONIBLE",
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _buscarCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText:
                                  "Buscar por nombre, categoría o código…",
                              prefixIcon: const Icon(Icons.search, size: 22),
                              filled: true,
                              fillColor: AppTokens.whiteSurface,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusMd),
                                borderSide: const BorderSide(
                                    color: AppTokens.greyBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusMd),
                                borderSide: const BorderSide(
                                    color: AppTokens.greyBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _categoria,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: "Categoría",
                              isDense: true,
                              filled: true,
                              fillColor: AppTokens.whiteSurface,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusMd),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text("Todas"),
                              ),
                              for (final c in categorias)
                                DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(c),
                                ),
                            ],
                            onChanged: (v) => setState(() => _categoria = v),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              label: const Text("Solo con stock"),
                              selected: _soloConStock,
                              onSelected: (v) =>
                                  setState(() => _soloConStock = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "${filtrados.length} producto${filtrados.length == 1 ? "" : "s"}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: filtrados.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  "No hay productos con los filtros actuales.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                24,
                              ),
                              itemCount: filtrados.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final p = filtrados[i];
                                return _ProductoStockTile(producto: p);
                              },
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

class _ProductoStockTile extends StatelessWidget {
  const _ProductoStockTile({required this.producto});

  final StockProduct producto;

  @override
  Widget build(BuildContext context) {
    final ok = producto.cantidad > 0;
    return Material(
      color: AppTokens.whiteSurface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.greyBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        producto.categoria,
                        if (producto.codigo != null &&
                            producto.codigo!.isNotEmpty)
                          "Cód. ${producto.codigo}",
                      ].join(" · "),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Disp.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ok
                          ? AppTokens.surfaceMuted
                          : const Color.fromARGB(255, 96, 31, 31)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${producto.cantidad}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ok ? Colors.black87 : AppTokens.redAction,
                      ),
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
