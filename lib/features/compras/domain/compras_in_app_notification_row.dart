/// Fila de `compras_in_app_notifications` para el usuario actual (rol Compras).
class ComprasInAppNotificationRow {
	const ComprasInAppNotificationRow({
		required this.id,
		required this.createdAt,
		required this.userId,
		required this.kind,
		required this.refId,
		required this.title,
		required this.body,
		this.readAt,
	});

	final String id;
	final DateTime createdAt;
	final String userId;
	final String kind;
	final String refId;
	final String title;
	final String body;
	final DateTime? readAt;

	bool get isUnread => readAt == null;

	factory ComprasInAppNotificationRow.fromJson(Map<String, dynamic> m) {
		final c = m["created_at"];
		final r = m["read_at"];
		return ComprasInAppNotificationRow(
			id: m["id"] as String,
			createdAt: c is DateTime ? c : DateTime.parse(c.toString()),
			userId: m["user_id"] as String,
			kind: m["kind"] as String,
			refId: m["ref_id"] as String,
			title: m["title"] as String,
			body: m["body"] as String,
			readAt: r == null
					? null
					: (r is DateTime ? r : DateTime.tryParse(r.toString())),
		);
	}
}
