import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../data/compras_stock_repository.dart";

final comprasStockRepositoryProvider = Provider<ComprasStockRepository>(
	(ref) => ComprasStockRepository(ref.watch(supabaseClientProvider)),
);
