/// Anotación sobre la plantilla PDF (coordenadas normalizadas 0–1 por página).
class WorkOrderPdfAnnotation {
	const WorkOrderPdfAnnotation({
		required this.id,
		required this.pageIndex,
		required this.type,
		required this.x,
		required this.y,
		this.text,
		this.width = 0.25,
		this.height = 0.06,
	});

	final String id;
	final int pageIndex;
	final String type; // text | check | signature
	final double x;
	final double y;
	final String? text;
	final double width;
	final double height;

	WorkOrderPdfAnnotation copyWith({
		double? x,
		double? y,
		String? text,
		double? width,
		double? height,
	}) {
		return WorkOrderPdfAnnotation(
			id: id,
			pageIndex: pageIndex,
			type: type,
			x: x ?? this.x,
			y: y ?? this.y,
			text: text ?? this.text,
			width: width ?? this.width,
			height: height ?? this.height,
		);
	}

	Map<String, dynamic> toJson() => {
				"id": id,
				"pageIndex": pageIndex,
				"type": type,
				"x": x,
				"y": y,
				if (text != null) "text": text,
				"width": width,
				"height": height,
			};

	static WorkOrderPdfAnnotation fromJson(Map<String, dynamic> m) {
		return WorkOrderPdfAnnotation(
			id: m["id"] as String? ?? "",
			pageIndex: (m["pageIndex"] as num?)?.toInt() ?? 0,
			type: m["type"] as String? ?? "text",
			x: (m["x"] as num?)?.toDouble() ?? 0,
			y: (m["y"] as num?)?.toDouble() ?? 0,
			text: m["text"] as String?,
			width: (m["width"] as num?)?.toDouble() ?? 0.25,
			height: (m["height"] as num?)?.toDouble() ?? 0.06,
		);
	}
}
