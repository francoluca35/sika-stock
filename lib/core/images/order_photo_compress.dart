import "dart:typed_data";

import "package:image/image.dart" as img;

/// Tope para adjuntos del pedido (~300 KB) — bajo egreso en Supabase Storage.
const int kMaxOrderPhotoBytes = 307200;

/// Lado más largo tras comprimir (suficiente para ver el producto en pantalla).
const int kMaxOrderPhotoLongestSide = 1024;

/// Calidad JPEG inicial al comprimir fotos de pedido.
const int kOrderPhotoJpegQualityStart = 78;

/// Comprime una imagen a JPEG liviano (≤ [kMaxOrderPhotoBytes], lado ≤ [kMaxOrderPhotoLongestSide]).
/// Si no se puede decodificar, devuelve `null`.
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

	resizeToMaxSide(kMaxOrderPhotoLongestSide);

	var quality = kOrderPhotoJpegQualityStart;
	Uint8List out = Uint8List.fromList(img.encodeJpg(image, quality: quality));

	while (out.length > kMaxOrderPhotoBytes && quality >= 42) {
		quality -= 6;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
	}

	var iterations = 0;
	while (out.length > kMaxOrderPhotoBytes && iterations < 10) {
		iterations++;
		final side = (longestSide(image) * 0.85).round().clamp(480, kMaxOrderPhotoLongestSide);
		resizeToMaxSide(side);
		quality = 72;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		while (out.length > kMaxOrderPhotoBytes && quality >= 36) {
			quality -= 5;
			out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		}
	}

	if (out.length > kMaxOrderPhotoBytes) {
		image = img.copyResize(image, width: 720, interpolation: img.Interpolation.linear);
		quality = 68;
		out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		while (out.length > kMaxOrderPhotoBytes && quality >= 32) {
			quality -= 4;
			out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
		}
	}

	if (out.length > kMaxOrderPhotoBytes) {
		return null;
	}

	return out;
}

/// Texto legible del tope de peso (p. ej. "300 KB").
String get kMaxOrderPhotoBytesLabel {
	final kb = (kMaxOrderPhotoBytes / 1024).round();
	return "$kb KB";
}
