/// Prioridad de un pedido (valores estables para persistencia futura).
enum OrderPriority {
	alta("ALTA", "Alta"),
	media("MEDIA", "Media"),
	baja("BAJA", "Baja");

	const OrderPriority(this.dbValue, this.label);

	final String dbValue;
	final String label;
}
