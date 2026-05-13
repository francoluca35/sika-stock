import "dart:typed_data";

import "package:excel/excel.dart";

/// Fila válida leída desde Excel para insertar en `stock_items`.
class StockExcelImportRow {
	const StockExcelImportRow({
		required this.filaExcel,
		required this.codigo,
		required this.nombre,
		required this.descripcionEmpresa,
		required this.descripcionFabricante,
		required this.categoria,
		required this.marca,
		required this.cantidad,
		required this.cantidadMinima,
		required this.cantidadMaxima,
	});

	final int filaExcel;
	final String codigo;
	final String nombre;
	final String descripcionEmpresa;
	final String descripcionFabricante;
	final String categoria;
	final String marca;
	final int cantidad;
	final int cantidadMinima;
	final int cantidadMaxima;

	Map<String, dynamic> toInsertMap() => {
				"codigo": codigo,
				"nombre": nombre,
				"descripcion_empresa": descripcionEmpresa,
				"descripcion_fabricante": descripcionFabricante,
				"categoria": categoria,
				"marca": marca,
				"cantidad": cantidad,
				"cantidad_minima": cantidadMinima,
				"cantidad_maxima": cantidadMaxima,
			};
}

class StockExcelParseResult {
	const StockExcelParseResult({
		required this.rows,
		required this.errores,
	});

	final List<StockExcelImportRow> rows;
	final List<String> errores;

	bool get tieneFilasValidas => rows.isNotEmpty;
}

/// Lee un `.xlsx` y mapea columnas por encabezado.
class StockExcelImporter {
	static StockExcelParseResult parseBytes(Uint8List bytes) {
		final errores = <String>[];
		try {
			final book = Excel.decodeBytes(bytes);
			if (book.tables.isEmpty) {
				return const StockExcelParseResult(rows: [], errores: ["El archivo no tiene hojas."]);
			}
			final sheet = book.tables.values.first;
			final filas = sheet.rows;
			if (filas.isEmpty) {
				return const StockExcelParseResult(rows: [], errores: ["La hoja está vacía."]);
			}

			final headerIdx = _indiceEncabezado(filas);
			if (headerIdx == null) {
				return const StockExcelParseResult(
					rows: [],
					errores: ["No se encontró una fila de encabezados."],
				);
			}

			final headers = _textosFila(filas[headerIdx]);
			final ancho = headers.length;
			final cols = _resolverColumnas(headers, ancho);

			if (cols.codigo == null && cols.nombre == null && ancho < 2) {
				return const StockExcelParseResult(
					rows: [],
					errores: [
						"No se reconocieron columnas de producto. "
						"Incluí al menos código o nombre en la primera fila.",
					],
				);
			}

			final rows = <StockExcelImportRow>[];
			for (var i = headerIdx + 1; i < filas.length; i++) {
				final filaExcel = i + 1;
				final celdas = _textosFila(filas[i], minWidth: ancho);
				if (_filaVacia(celdas)) continue;

				final codigo = _valor(celdas, cols.codigo);
				var nombre = _valor(celdas, cols.nombre);
				if (nombre.isEmpty) {
					nombre = codigo.isNotEmpty ? codigo : "Producto fila $filaExcel";
				}

				final descEmp = _valor(celdas, cols.descripcionEmpresa);
				final descFab = _valor(celdas, cols.descripcionFabricante);
				final categoria = _valor(celdas, cols.categoria);
				final marca = _valor(celdas, cols.marca);
				final cant = _parseCantidadOpcional(_valor(celdas, cols.cantidad)) ?? 0;
				var min = _parseCantidadOpcional(_valor(celdas, cols.cantidadMinima)) ?? 0;
				var max = _parseCantidadOpcional(_valor(celdas, cols.cantidadMaxima)) ?? 0;
				if (max > 0 && min > max) {
					max = min;
				}

				rows.add(
					StockExcelImportRow(
						filaExcel: filaExcel,
						codigo: codigo,
						nombre: nombre,
						descripcionEmpresa: descEmp,
						descripcionFabricante: descFab,
						categoria: categoria,
						marca: marca,
						cantidad: cant,
						cantidadMinima: min,
						cantidadMaxima: max,
					),
				);
			}

			if (rows.isEmpty && errores.isEmpty) {
				errores.add("No hay filas de datos debajo del encabezado.");
			}

			return StockExcelParseResult(rows: rows, errores: errores);
		} catch (e) {
			return StockExcelParseResult(
				rows: [],
				errores: ["No se pudo leer el Excel: $e"],
			);
		}
	}

	static int? _indiceEncabezado(List<List<Data?>> filas) {
		for (var i = 0; i < filas.length && i < 10; i++) {
			final textos = _textosFila(filas[i]);
			if (textos.any((t) => t.trim().isNotEmpty)) {
				return i;
			}
		}
		return null;
	}

	static List<String> _textosFila(List<Data?> fila, {int? minWidth}) {
		final textos = fila.map((c) => _celdaTexto(c)).toList();
		if (minWidth != null && textos.length < minWidth) {
			textos.addAll(List.filled(minWidth - textos.length, ""));
		}
		return textos;
	}

	static String _celdaTexto(Data? celda) {
		if (celda == null) return "";
		final v = celda.value;
		if (v == null) return "";
		return v.toString().trim();
	}

	static bool _filaVacia(List<String> celdas) =>
			celdas.every((c) => c.trim().isEmpty);

	static String _valor(List<String> celdas, int? idx) {
		if (idx == null || idx < 0 || idx >= celdas.length) return "";
		return celdas[idx].trim();
	}

	static int? _parseCantidad(String raw) {
		final t = raw.trim().replaceAll(",", ".");
		if (t.isEmpty) return null;
		final d = double.tryParse(t);
		if (d == null || d < 0 || d != d.roundToDouble()) {
			final n = int.tryParse(t);
			if (n == null || n < 0) return null;
			return n;
		}
		return d.round();
	}

	/// Vacío o inválido → 0.
	static int? _parseCantidadOpcional(String raw) {
		if (raw.trim().isEmpty) return 0;
		return _parseCantidad(raw) ?? 0;
	}

	static int? _colOr(int? resolved, int fallback, int ancho) {
		if (resolved != null) return resolved;
		return fallback < ancho ? fallback : null;
	}

	static String _normHeader(String raw) {
		var s = raw.toLowerCase().trim();
		const map = {
			"á": "a",
			"é": "e",
			"í": "i",
			"ó": "o",
			"ú": "u",
			"ñ": "n",
			"º": "",
			"°": "",
		};
		for (final e in map.entries) {
			s = s.replaceAll(e.key, e.value);
		}
		return s.replaceAll(RegExp(r"\s+"), " ");
	}

	static _ColumnMap _resolverColumnas(List<String> headers, int ancho) {
		final norm = headers.map(_normHeader).toList();

		int? findExact(Iterable<String> exact) {
			for (var i = 0; i < norm.length; i++) {
				if (exact.contains(norm[i])) return i;
			}
			return null;
		}

		int? findContains(Iterable<String> needles) {
			for (var i = 0; i < norm.length; i++) {
				for (final n in needles) {
					if (norm[i].contains(n)) return i;
				}
			}
			return null;
		}

		int? find(Iterable<String> exact, Iterable<String> contains) =>
				findExact(exact) ?? findContains(contains);

		// Resolver máximo antes que mínimo (evita ambigüedad con "min" en "maximo").
		final idxMax = find(
			{"maximo", "maxima", "cantidad maxima", "stock maximo"},
			{"maximo", "maxima"},
		);
		final idxMin = find(
			{"minimo", "minima", "cantidad minima", "stock minimo"},
			{"minimo", "minima"},
		);

		return _ColumnMap(
			codigo: _colOr(
				find(
					{"codigo", "code"},
					{"codigo", "code", "n producto", "numero producto"},
				),
				0,
				ancho,
			),
			nombre: _colOr(
				find({"nombre", "name", "producto"}, {"nombre", "name"}),
				1,
				ancho,
			),
			descripcionEmpresa: _colOr(
				find(
					{
						"descripcion empresa",
						"desc empresa",
						"descripcion_empresa",
					},
					{"descripcion empresa", "desc empresa"},
				),
				2,
				ancho,
			),
			descripcionFabricante: _colOr(
				find(
					{
						"descripcion fabricante",
						"desc fabricante",
						"descripcion_fabricante",
					},
					{"descripcion fabricante", "desc fabricante"},
				),
				3,
				ancho,
			),
			categoria: _colOr(
				find(
					{"categoria", "category", "uso", "rubro"},
					{"categoria", "category", "rubro"},
				),
				4,
				ancho,
			),
			marca: _colOr(
				find({"marca", "brand"}, {"marca", "brand"}),
				5,
				ancho,
			),
			cantidad: _colOr(
				find(
					{"cantidad", "qty", "quantity", "stock"},
					{"cantidad", "stock"},
				),
				6,
				ancho,
			),
			cantidadMaxima: _colOr(idxMax, 7, ancho),
			cantidadMinima: _colOr(idxMin, 8, ancho),
		);
	}
}

class _ColumnMap {
	const _ColumnMap({
		this.codigo,
		this.nombre,
		this.descripcionEmpresa,
		this.descripcionFabricante,
		this.categoria,
		this.marca,
		this.cantidad,
		this.cantidadMinima,
		this.cantidadMaxima,
	});

	final int? codigo;
	final int? nombre;
	final int? descripcionEmpresa;
	final int? descripcionFabricante;
	final int? categoria;
	final int? marca;
	final int? cantidad;
	final int? cantidadMinima;
	final int? cantidadMaxima;
}
