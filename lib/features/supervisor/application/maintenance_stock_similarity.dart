import "../../stock/domain/stock_product.dart";
import "../domain/maintenance_order.dart";

/// Resultado de comparar el pedido con el catálogo (mejor coincidencia y cantidad).
({bool haySuficiente, StockProduct? match, int disponible}) analizarStockPedido(
	MaintenanceOrder pedido,
	List<StockProduct> catalog,
) {
	final match = mejorStockMatchParaPedido(pedido.producto, catalog);
	if (match == null) {
		return (haySuficiente: false, match: null, disponible: 0);
	}
	final ok = match.cantidad >= pedido.quantity;
	return (haySuficiente: ok, match: match, disponible: match.cantidad);
}

/// Comparación usando una línea de catálogo elegida por el supervisor (sin similitud de texto).
({bool haySuficiente, StockProduct? match, int disponible}) analizarStockLineaExacta(
	StockProduct linea,
	int cantidadPedida,
) {
	final ok = linea.cantidad >= cantidadPedida;
	return (haySuficiente: ok, match: linea, disponible: linea.cantidad);
}

/// Mejor línea de catálogo para el texto del pedido, o `null` si no hay coincidencia útil.
StockProduct? mejorStockMatchParaPedido(
	String productoPedido,
	List<StockProduct> catalog, {
	String? stockItemIdPreferido,
}) {
	final scored = mejorStockMatchConScore(
		productoPedido,
		catalog,
		stockItemIdPreferido: stockItemIdPreferido,
	);
	return scored?.product;
}

/// Misma búsqueda que [mejorStockMatchParaPedido], incluyendo el score de similitud.
({StockProduct product, int score})? mejorStockMatchConScore(
	String productoPedido,
	List<StockProduct> catalog, {
	String? stockItemIdPreferido,
}) {
	if (stockItemIdPreferido != null && stockItemIdPreferido.isNotEmpty) {
		for (final p in catalog) {
			if (p.id == stockItemIdPreferido) {
				return (product: p, score: 999);
			}
		}
	}
	final matches = stockSimilarScoredToPedido(productoPedido, catalog);
	if (matches.isEmpty) return null;
	final best = matches.first;
	return (product: best.p, score: best.score);
}

/// `true` cuando el match es débil / parcial (conviene ofrecer alta de producto nuevo).
bool esCoincidenciaParcial(int score) => score > 0 && score < 100;

/// Coincidencias con score (ordenadas de mayor a menor).
List<({StockProduct p, int score})> stockSimilarScoredToPedido(
	String productoPedido,
	List<StockProduct> catalog,
) {
	final raw = productoPedido.split(RegExp(r"[\r\n]+")).first.trim();
	final q = _normalize(raw);
	if (q.isEmpty) return [];

	final scored = <({StockProduct p, int score})>[];
	for (final p in catalog) {
		final s = _similarityScore(q, p);
		if (s > 0) {
			scored.add((p: p, score: s));
		}
	}
	scored.sort((a, b) {
		final byScore = b.score.compareTo(a.score);
		if (byScore != 0) return byScore;
		final byQty = b.p.cantidad.compareTo(a.p.cantidad);
		if (byQty != 0) return byQty;
		return _normalize(a.p.nombre).compareTo(_normalize(b.p.nombre));
	});
	return scored;
}

/// Coincidencias entre el texto del pedido de mantenimiento y el catálogo de stock.
///
/// Normaliza acentos, ignora stopwords, expande códigos alfanuméricos (p. ej. `8091led`),
/// puntúa nombre / código / marca / descripciones y exige cobertura mínima de tokens
/// significativos para evitar falsos positivos genéricos.
List<StockProduct> stockSimilarToPedido(
	String productoPedido,
	List<StockProduct> catalog,
) {
	return stockSimilarScoredToPedido(productoPedido, catalog)
			.map((e) => e.p)
			.toList();
}

/// Hay al menos una línea de catálogo similar con unidades disponibles.
bool hayStockDisponibleEnCoincidencias(List<StockProduct> coincidencias) =>
		coincidencias.any((p) => p.cantidad > 0);

const _stopwords = <String>{
	"de",
	"del",
	"la",
	"el",
	"los",
	"las",
	"un",
	"una",
	"unos",
	"unas",
	"y",
	"o",
	"en",
	"para",
	"con",
	"sin",
	"por",
	"al",
	"a",
	"the",
	"of",
	"and",
	"mm",
	"cm",
	"mts",
	"mt",
	"und",
	"uds",
};

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

/// Tokens útiles del pedido (sin stopwords) + partes de códigos compuestos.
List<String> _significantTokens(String normalizedQuery) {
	final base = _tokens(normalizedQuery)
			.where((t) => !_stopwords.contains(t))
			.toList();
	final out = <String>{};
	for (final t in base) {
		out.add(t);
		for (final part in _splitAlphaNum(t)) {
			if (part.length >= 2 && !_stopwords.contains(part)) {
				out.add(part);
			}
		}
	}
	return out.toList();
}

/// `8091led` → `8091`, `led`.
List<String> _splitAlphaNum(String token) {
	return token
			.split(RegExp(r"(?<=[a-z])(?=[0-9])|(?<=[0-9])(?=[a-z])"))
			.where((p) => p.isNotEmpty)
			.toList();
}

bool _isDistinctiveToken(String t) =>
		t.length >= 4 && RegExp(r"\d").hasMatch(t);

bool _fieldContainsToken(String field, String token) {
	if (field.isEmpty || token.isEmpty) return false;
	if (field.contains(token)) return true;
	// El catálogo puede tener el código partido (`8091` vs pedido `8091led`).
	if (token.length >= 4) {
		for (final part in _splitAlphaNum(token)) {
			if (part.length >= 3 && field.contains(part)) return true;
		}
	}
	return false;
}

({String nombre, String cat, String cod, String marca, String desc, String blob})
		_fields(StockProduct p) {
	final nombre = _normalize(p.nombre);
	final cat = _normalize(p.categoria);
	final cod = _normalize(p.codigo ?? "");
	final marca = _normalize(p.marca);
	final desc = _normalize(
		"${p.descripcionEmpresa} ${p.descripcionFabricante}",
	);
	return (
		nombre: nombre,
		cat: cat,
		cod: cod,
		marca: marca,
		desc: desc,
		blob: "$nombre $cat $cod $marca $desc",
	);
}

int _matchedSignificantCount(List<String> queryTokens, StockProduct p) {
	final f = _fields(p);
	var matched = 0;
	for (final t in queryTokens) {
		if (_fieldContainsToken(f.nombre, t) ||
				_fieldContainsToken(f.cat, t) ||
				_fieldContainsToken(f.cod, t) ||
				_fieldContainsToken(f.marca, t) ||
				_fieldContainsToken(f.desc, t)) {
			matched++;
		}
	}
	return matched;
}

/// Cobertura mínima de tokens significativos del pedido.
int _minMatchedTokensRequired(int queryTokenCount, {required bool hasDistinctiveHit}) {
	if (queryTokenCount <= 1) return 1;
	if (hasDistinctiveHit) return 1;
	if (queryTokenCount == 2) return 2;
	// ≥3: al menos la mitad (ceil), con tope práctico de 3.
	final half = (queryTokenCount + 1) ~/ 2;
	return half > 3 ? 3 : half;
}

int _similarityScore(String queryNorm, StockProduct p) {
	final f = _fields(p);
	var score = 0;

	final fraseCompleta =
			queryNorm.isNotEmpty && f.blob.contains(queryNorm);
	if (fraseCompleta) {
		score += 120 + queryNorm.length;
	}

	// Nombre del catálogo contenido en el pedido (match inverso).
	final nombreEnPedido = f.nombre.length >= 5 && queryNorm.contains(f.nombre);
	if (nombreEnPedido) {
		score += 90 + f.nombre.length;
	}

	// Código exacto / contenido en el pedido.
	if (f.cod.isNotEmpty && f.cod.length >= 3) {
		if (queryNorm.contains(f.cod) || f.cod == queryNorm) {
			score += 140;
		}
	}

	final qt = _significantTokens(queryNorm);
	var distinctiveHit = false;
	for (final t in qt) {
		final inNombre = _fieldContainsToken(f.nombre, t);
		final inCat = _fieldContainsToken(f.cat, t);
		final inCod = _fieldContainsToken(f.cod, t);
		final inMarca = _fieldContainsToken(f.marca, t);
		final inDesc = _fieldContainsToken(f.desc, t);
		if (inNombre) score += 14 + t.length;
		if (inCat) score += 5 + t.length ~/ 2;
		if (inCod) score += 22 + t.length;
		if (inMarca) score += 10 + t.length ~/ 2;
		if (inDesc) score += 8 + t.length ~/ 2;
		if (_isDistinctiveToken(t) &&
				(inNombre || inCod || inDesc || inMarca)) {
			distinctiveHit = true;
			score += 35;
		}
	}

	if (score <= 0) return 0;
	if (fraseCompleta || nombreEnPedido) return score;
	if (f.cod.isNotEmpty &&
			f.cod.length >= 3 &&
			(queryNorm.contains(f.cod) || f.cod == queryNorm)) {
		return score;
	}

	if (qt.isEmpty) return 0;

	final matched = _matchedSignificantCount(qt, p);
	final minRequired = _minMatchedTokensRequired(
		qt.length,
		hasDistinctiveHit: distinctiveHit,
	);
	if (matched < minRequired) return 0;

	return score;
}
