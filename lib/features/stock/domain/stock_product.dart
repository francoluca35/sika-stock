/// Ítem de inventario (`public.stock_items` en Supabase).
class StockProduct {
	const StockProduct({
		required this.id,
		required this.nombre,
		required this.categoria,
		required this.cantidad,
		this.codigo,
	});

	final String id;
	final String nombre;
	final String categoria;

	/// Unidades disponibles (≥ 0).
	final int cantidad;

	final String? codigo;

	factory StockProduct.fromJson(Map<String, dynamic> json) {
		final cod = json["codigo"];
		return StockProduct(
			id: json["id"] as String,
			nombre: (json["nombre"] as String).trim(),
			categoria: (json["categoria"] as String).trim(),
			cantidad: (json["cantidad"] as num).toInt(),
			codigo: cod is String && cod.trim().isNotEmpty ? cod.trim() : null,
		);
	}
}
