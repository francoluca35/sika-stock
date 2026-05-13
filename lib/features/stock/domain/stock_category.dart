/// Fila de `public.stock_categories`.
class StockCategory {
	const StockCategory({
		required this.id,
		required this.name,
	});

	final String id;
	final String name;

	factory StockCategory.fromJson(Map<String, dynamic> json) {
		return StockCategory(
			id: json["id"] as String,
			name: (json["name"] as String).trim(),
		);
	}
}
