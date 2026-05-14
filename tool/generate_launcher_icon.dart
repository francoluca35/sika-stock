import "dart:io";

import "package:image/image.dart" as img;

/// Genera assets/icon_launcher.png (1024×1024) con el logo centrado y margen
/// para iconos adaptativos de Android y PWA web.
void main() {
	final sourceBytes = File("assets/sika.png").readAsBytesSync();
	final source = img.decodeImage(sourceBytes);
	if (source == null) {
		stderr.writeln("No se pudo leer assets/sika.png");
		exit(1);
	}

	const size = 1024;
	const fillRatio = 0.72;
	final canvas = img.Image(width: size, height: size);
	img.fill(canvas, color: img.ColorRgb8(0, 0, 0));

	final targetW = (size * fillRatio).round();
	final targetH = (source.height * targetW / source.width).round();
	final resized = img.copyResize(source, width: targetW, height: targetH);
	final x = (size - targetW) ~/ 2;
	final y = (size - targetH) ~/ 2;
	img.compositeImage(canvas, resized, dstX: x, dstY: y);

	File("assets/icon_launcher.png").writeAsBytesSync(img.encodePng(canvas));
	print("Generado assets/icon_launcher.png (${size}x$size)");
}
