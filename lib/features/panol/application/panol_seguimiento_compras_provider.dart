import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../compras/application/compras_stock_repository_provider.dart";
import "../presentation/widgets/producto_seguimiento_panel.dart";
import "panol_seguimiento_mapper.dart";

/// Productos en seguimiento por orden de compra (solicitudes pañol → compras).
final panolSeguimientoComprasProvider =
		FutureProvider<List<ProductoSeguimiento>>((ref) async {
	ref.keepAlive();
	final rows = await ref.read(comprasStockRepositoryProvider).fetchPanolStockRequests();
	return productosSeguimientoDesdeComprasRequests(rows);
});
