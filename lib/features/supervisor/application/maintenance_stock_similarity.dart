import "../../stock/domain/stock_product.dart";
import "../domain/maintenance_order.dart";

/// Resultado de comparar el pedido con el catálogo (mejor coincidencia y cantidad).
({bool haySuficiente, StockProduct? match, int disponible}) analizarStockPedido(
	MaintenanceOrder pedido,
	List<StockProduct> catalog,
) {
	final matches = stockSimilarToPedido(pedido.producto, catalog);
	if (matches.isEmpty) {
		return (haySuficiente: false, match: null, disponible: 0);
	}
	final best = matches.first;
	final ok = best.cantidad >= pedido.quantity;
	return (haySuficiente: ok, match: best, disponible: best.cantidad);
}

/// Comparación usando una línea de catálogo elegida por el supervisor (sin similitud de texto).
({bool haySuficiente, StockProduct? match, int disponible}) analizarStockLineaExacta(
	StockProduct linea,
	int cantidadPedida,
) {
	final ok = linea.cantidad >= cantidadPedida;
	return (haySuficiente: ok, match: linea, disponible: linea.cantidad);
}

/// Coincidencias entre el texto del pedido de mantenimiento y el catálogo de stock.
///
/// Usa normalización, coincidencia por frase y por tokens (palabras ≥ 2 caracteres).
/// Exige cobertura mínima de tokens para evitar falsos positivos
/// (p. ej. solo «tablero» no alcanza frente a «tablero servicios fluidmaster»).
List<StockProduct> stockSimilarToPedido(
	String productoPedido,
	List<StockProduct> catalog,
) {
	final q = _normalize(productoPedido);
	if (q.isEmpty) return [];

	final scored = <({StockProduct p, int score})>[];
	for (final p in catalog) {
		final s = _similarityScore(q, p);
		if (s > 0) {
			scored.add((p: p, score: s));
		}
	}
	scored.sort((a, b) {
		final ha = a.p.cantidad > 0;
		final hb = b.p.cantidad > 0;
		if (ha != hb) {
			return ha ? -1 : 1;
		}
		final byScore = b.score.compareTo(a.score);
		if (byScore != 0) return byScore;
		return _normalize(a.p.nombre).compareTo(_normalize(b.p.nombre));
	});
	return scored.map((e) => e.p).toList();
}

/// Hay al menos una línea de catálogo similar con unidades disponibles.
bool hayStockDisponibleEnCoincidencias(List<StockProduct> coincidencias) =>
		coincidencias.any((p) => p.cantidad > 0);

String _normalize(String s) {
	var x = s.toLowerCase().trim();
	const accents = {
		"á": "a",
		"é": "e",
		"í": "i",
		"ó": "o",
		"ú": "u",
		"ü": "u",
		"ñ": "n",
	};
	for (final e in accents.entries) {
		x = x.replaceAll(e.key, e.value);
	}
	return x;
}

/// Tokens alfanuméricos de longitud ≥ 2.
List<String> _tokens(String normalizedQuery) {
	return normalizedQuery
			.split(RegExp(r"[^a-z0-9]+"))
			.where((t) => t.length >= 2)
			.toList();
}

int _matchedTokenCount(List<String> queryTokens, StockProduct p) {
	final nombre = _normalize(p.nombre);
	final cat = _normalize(p.categoria);
	final cod = _normalize(p.codigo ?? "");
	var matched = 0;
	for (final t in queryTokens) {
		if (nombre.contains(t) || cat.contains(t) || cod.contains(t)) {
			matched++;
		}
	}
	return matched;
}

/// Cantidad mínima de tokens del pedido que deben aparecer en la línea de catálogo.
int _minMatchedTokensRequired(int queryTokenCount) {
	if (queryTokenCount <= 1) return 1;
	if (queryTokenCount == 2) return 2;
	// ≥3 tokens: al menos la mitad redondeando hacia arriba.
	return (queryTokenCount + 1) ~/ 2;
}

int _similarityScore(String queryNorm, StockProduct p) {
	final nombre = _normalize(p.nombre);
	final cat = _normalize(p.categoria);
	final cod = _normalize(p.codigo ?? "");
	final blob = "$nombre $cat $cod";

	var score = 0;
	final fraseCompleta =
			queryNorm.isNotEmpty && blob.contains(queryNorm);
	if (fraseCompleta) {
		score += 100 + queryNorm.length;
	}
	final qt = _tokens(queryNorm);
	for (final t in qt) {
		if (nombre.contains(t)) {
			score += 12 + t.length;
		}
		if (cat.contains(t)) {
			score += 6 + t.length ~/ 2;
		}
		if (cod.contains(t)) {
			score += 18 + t.length;
		}
	}

	if (score <= 0) return 0;

	// Frase completa del pedido contenida en la línea → coincidencia válida.
	if (fraseCompleta) return score;

	if (qt.isEmpty) return 0;

	final matched = _matchedTokenCount(qt, p);
	final minRequired = _minMatchedTokensRequired(qt.length);
	if (matched < minRequired) return 0;

	return score;
}
