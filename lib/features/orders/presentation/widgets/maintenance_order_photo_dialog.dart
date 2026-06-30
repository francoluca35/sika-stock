import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Imagen de pedido con cache local (evita re-descargar desde Supabase).
class MaintenanceOrderPhotoView extends StatelessWidget {
	const MaintenanceOrderPhotoView({
		super.key,
		required this.imageUrl,
		this.fit = BoxFit.contain,
		this.height,
	});

	final String imageUrl;
	final BoxFit fit;
	final double? height;

	@override
	Widget build(BuildContext context) {
		final url = imageUrl.trim();
		return CachedNetworkImage(
			imageUrl: url,
			fit: fit,
			height: height,
			memCacheWidth: 1024,
			maxWidthDiskCache: 1024,
			placeholder: (_, __) => SizedBox(
				height: height ?? 220,
				child: const Center(
					child: CircularProgressIndicator(strokeWidth: 2),
				),
			),
			errorWidget: (_, __, ___) => Container(
				height: height,
				padding: const EdgeInsets.all(20),
				decoration: BoxDecoration(
					color: AppTokens.surfaceMuted,
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				),
				child: Text(
					"No se pudo cargar la imagen.\nComprobá la conexión o que la foto exista en el servidor.",
					textAlign: TextAlign.center,
					style: TextStyle(
						fontSize: 14,
						height: 1.4,
						color: Colors.grey.shade800,
					),
				),
			),
		);
	}
}

/// Muestra la foto que adjuntó mantenimiento al pedido.
void showMaintenanceOrderPhotoDialog(
	BuildContext context,
	String imageUrl, {
	String title = "Imagen del pedido",
}) {
	final url = imageUrl.trim();
	if (url.isEmpty) return;

	final ancho = MediaQuery.sizeOf(context).width;
	final dialogW = ancho > 560 ? 480.0 : (ancho - 40).clamp(280.0, 520.0);

	showDialog<void>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: Text(title),
			content: SizedBox(
				width: dialogW,
				child: InteractiveViewer(
					minScale: 0.5,
					maxScale: 4,
					child: MaintenanceOrderPhotoView(imageUrl: url),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(ctx),
					child: const Text("Cerrar"),
				),
			],
		),
	);
}

bool maintenanceOrderTieneImagen(String? imagenUrl) {
	final u = imagenUrl?.trim();
	return u != null && u.isNotEmpty;
}
