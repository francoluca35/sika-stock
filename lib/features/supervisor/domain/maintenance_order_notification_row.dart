/// Fila de `maintenance_order_notifications` para el usuario actual.
class MaintenanceOrderNotificationRow {
	const MaintenanceOrderNotificationRow({
		required this.id,
		required this.createdAt,
		required this.orderId,
		required this.kind,
		required this.title,
		required this.body,
		this.readAt,
	});

	final String id;
	final DateTime createdAt;
	final String orderId;
	final String kind;
	final String title;
	final String body;
	final DateTime? readAt;

	bool get isUnread => readAt == null;

	factory MaintenanceOrderNotificationRow.fromJson(Map<String, dynamic> m) {
		final c = m["created_at"];
		final r = m["read_at"];
		return MaintenanceOrderNotificationRow(
			id: m["id"] as String,
			createdAt: c is DateTime ? c : DateTime.parse(c.toString()),
			orderId: m["order_id"] as String,
			kind: m["kind"] as String,
			title: m["title"] as String,
			body: m["body"] as String,
			readAt: r == null
					? null
					: (r is DateTime ? r : DateTime.tryParse(r.toString())),
		);
	}
}
