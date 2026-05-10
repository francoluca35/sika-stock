import "dart:typed_data";

import "package:image/image.dart" as img;

/// Tope para adjuntos del pedido (~1,5 MB).
const int kMaxOrderPhotoBytes = 1572864;

/// Comprime una imagen (JPEG/PNG/WebP según soporte del decoder) a JPEG con tamaño ≤ [kMaxOrderPhotoBytes].
/// Pensado para fotos de cámara de alto megapixel.
/// Si no se puede decodificar, devuelve `null` (no forzar bytes corruptos).
Uint8List? compressOrderPhotoBytes(Uint8List raw) {
	final decoded = img.decodeImage(raw);
	if (decoded == null) {
		return null;
	}

	img.Image image = decoded;

	int longestSide(img.Image i) => i.width > i.height ? i.width : i.height;

	void resizeToMaxSide(int maxSide) {
		if (longestSide(image) <= maxSide) return;
		if (image.width >= image.height) {
			image = img.copyResize(
				image,
				width: maxSide,
				interpolation: img.Interpolation.linear,
			);
		} else {
			image = img.copyResize(
				image,
				height: maxSide,
				interpolation: img.Interpolation.linear,
			);
		}
	}

	resizeToMaxSide(2048);

	var quality = 88;
	Uint8List out = Uint8List.fromList(img.encodeJpg(image, quality: quality));

	while (out.length > kMaxOrderPhotoBytes && quality >= 38) {
		quality -= 8;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
	}

	var iterations = 0;
	while (out.length > kMaxOrderPhotoBytes && iterations < 14) {
		iterations++;
		final side = (longestSide(image) * 0.82).round().clamp(360, 8192);
		resizeToMaxSide(side);
		quality = 84;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		while (out.length > kMaxOrderPhotoBytes && quality >= 26) {
			quality -= 6;
			out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		}
	}

	if (out.length > kMaxOrderPhotoBytes) {
		image = img.copyResize(image, width: 720, interpolation: img.Interpolation.linear);
		quality = 72;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		while (out.length > kMaxOrderPhotoBytes && quality >= 22) {
			quality -= 5;
			out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		}
	}

	if (out.length > kMaxOrderPhotoBytes) {
		image = img.copyResize(image, width: 480, interpolation: img.Interpolation.linear);
		quality = 62;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		while (out.length > kMaxOrderPhotoBytes && quality >= 18) {
			quality -= 4;
			out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		}
	}

	return out;
}
