/// Ítem de inventario (`public.stock_items` en Supabase).
class StockProduct {
	const StockProduct({
		required this.id,
		required this.nombre,
		required this.categoria,
		required this.cantidad,
		required this.descripcionEmpresa,
		required this.descripcionFabricante,
		required this.marca,
		required this.cantidadMinima,
		required this.cantidadMaxima,
		this.codigo,
	});

	final String id;
	final String nombre;
	final String categoria;

	/// Unidades disponibles (≥ 0).
	final int cantidad;

	/// Alerta si `cantidad` queda por debajo (0 = sin umbral).
	final int cantidadMinima;

	/// Alerta si `cantidad` supera el máximo (0 = sin umbral).
	final int cantidadMaxima;

	final String? codigo;
	final String descripcionEmpresa;
	final String descripcionFabricante;
	final String marca;

	factory StockProduct.fromJson(Map<String, dynamic> json) {
		final cod = json["codigo"];
		return StockProduct(
			id: json["id"] as String,
			nombre: (json["nombre"] as String).trim(),
			categoria: (json["categoria"] as String).trim(),
			cantidad: (json["cantidad"] as num).toInt(),
			cantidadMinima: (json["cantidad_minima"] as num?)?.toInt() ?? 0,
			cantidadMaxima: (json["cantidad_maxima"] as num?)?.toInt() ?? 0,
			codigo: cod is String && cod.trim().isNotEmpty ? cod.trim() : null,
			descripcionEmpresa: (json["descripcion_empresa"] as String? ?? "").trim(),
			descripcionFabricante: (json["descripcion_fabricante"] as String? ?? "").trim(),
			marca: (json["marca"] as String? ?? "").trim(),
		);
	}
}
