import "../../stock/domain/stock_product.dart";

/// Coincidencias entre el texto del pedido de mantenimiento y el catálogo de stock.
///
/// Usa normalización, coincidencia por frase y por tokens (palabras ≥ 2 caracteres).
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

int _similarityScore(String queryNorm, StockProduct p) {
	final nombre = _normalize(p.nombre);
	final cat = _normalize(p.categoria);
	final cod = _normalize(p.codigo ?? "");
	final blob = "$nombre $cat $cod";

	var score = 0;
	if (queryNorm.isNotEmpty && blob.contains(queryNorm)) {
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
	return score;
}
