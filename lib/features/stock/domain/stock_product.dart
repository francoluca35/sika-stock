/// Ítem de inventario para consulta (supervisor / listados).
///
/// La fuente real será Supabase cuando exista la tabla de stock.
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
}
